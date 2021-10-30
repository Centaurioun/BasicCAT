﻿B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=6.51
@EndOfDesignText@
Sub Class_Globals
	Private fx As JFX
	Private frm As Form
	Private ListView1 As ListView
	Private result As Boolean=False
End Sub

'Initializes the object. You can add parameters to this method if needed.
Public Sub Initialize
	frm.Initialize("frm",600,600)
	frm.RootPane.LoadLayout("importDialog")
End Sub

Public Sub ShowAndWait(path As String,importType As String) As Boolean
	loadFile(path,importType)
	frm.ShowAndWait
	Return result
End Sub

Sub loadFile(path As String,importType As String)
	Log(path)
	Log(importType)
	Select importType
		Case "tm"
			loadTM(path)
		Case "term"
			loadTerm(path)
	End Select
End Sub

Sub loadTM(path As String)
	If path.ToLowerCase.EndsWith(".txt") Then
		importTMTxt(path)
	Else If path.ToLowerCase.EndsWith(".xlsx") Then
			importTMXlsx(path)
	else if path.ToLowerCase.EndsWith(".tmx") Then
		importTMX(path,Main.currentProject.projectFile.Get("source"),Main.currentProject.projectFile.Get("target"))
	End If
End Sub

Sub importTMTxt(path As String)
	Try
		Dim content As String
		content=File.ReadString(path,"")
		Dim segments As List
		segments=Regex.Split(CRLF,content)
		Dim i As Int=0
		For Each line As String In segments
			Dim source,target As String
			source=Regex.Split("	",line)(0)
			target=Regex.Split("	",line)(1)
			i=i+1
			ListView1.Items.Add(buildTMItemText(source,target))
			If i=5 Then
				ListView1.Items.Add("......")
				Exit
			End If
		Next
	Catch
		fx.Msgbox(frm,"Invalid file","")
		Log(LastException)
	End Try

End Sub

Sub importTMXlsx(path As String)
	Try
		Dim wb As PoiWorkbook
		wb.InitializeExisting(path,"","")
        Dim i As Int=0
		Dim sheet1 As PoiSheet = wb.GetSheet(0)
		For Each row As PoiRow In sheet1.Rows
			Dim source,target As String
			source=row.GetCell(0).ValueString
			target=row.GetCell(1).ValueString
			i=i+1
			ListView1.Items.Add(buildTMItemText(source,target))
			If i=5 Then
				ListView1.Items.Add("......")
				Exit
			End If
		Next
		wb.Close
	Catch
		fx.Msgbox(frm,"Invalid file","")
		Log(LastException)
	End Try

End Sub

Sub importTMX(path As String,sourceLang As String,targetLang As String)
	Dim importer As TMXImporter
	importer.Initialize
	Try
		Dim tmxString As String
		tmxString=File.ReadString(path,"")
		tmxString=XMLUtils.pickSmallerXML(tmxString,"tu","body")
		Dim segments As List=importer.importedAccurateList2(tmxString,File.GetName(path),sourceLang,targetLang)
		Dim i As Int
		For Each segment As List In segments
			i=i+1
			ListView1.Items.Add(buildTMItemText(segment.Get(0),segment.Get(1)))
			If i=5 Then
				ListView1.Items.Add("......")
				Exit
			End If
		Next
	Catch
		fx.Msgbox(frm,"Invalid file","")
		Log(LastException)
	End Try
End Sub

Sub loadTerm(path As String)
	If path.ToLowerCase.EndsWith(".txt") Then
		importTermTxt(path)
	else if path.ToLowerCase.EndsWith(".tbx") Then
		importTBX(path)
	else if path.ToLowerCase.EndsWith(".xlsx") Then
		importedTermXlsx(path)
	End If
End Sub

Sub importedTermXlsx(path As String)
	Dim wb As PoiWorkbook
	wb.InitializeExisting(path,"","")
	Dim sheet1 As PoiSheet=wb.GetSheet(0)
	Dim i As Int=0
	For Each row As PoiRow In sheet1.Rows
		Dim terminfo As Map
		terminfo.Initialize
		Dim targetMap As Map
		targetMap.Initialize
		Dim source,target,note,tag As String
		source=row.GetCell(0).ValueString
		target=row.GetCell(1).ValueString
		Try
			note=row.GetCell(2).ValueString
			tag=row.GetCell(3).ValueString
		Catch
			Log(LastException)
		End Try
		i=i+1
		ListView1.Items.Add(buildTermItemText(source,target,note,tag,""))
		If i=5 Then
			ListView1.Items.Add("......")
			Exit
		End If
	Next
End Sub

Sub importTermTxt(path As String)
	Dim content As String
	content=File.ReadString(path,"")
	Dim segments As List
	segments=Regex.Split(CRLF,content)
	Dim i As Int=0
	For Each line As String In segments
		Dim source,target,note,tag As String
		source=Regex.Split("	",line)(0)
		target=Regex.Split("	",line)(1)
		Try
			note=Regex.Split("	",line)(2)
		Catch
			Log(LastException)
		End Try
		Try
			tag=Regex.Split("	",line)(3)
		Catch
			Log(LastException)
		End Try
		i=i+1
		ListView1.Items.Add(buildTermItemText(source,target,note,tag,""))
		If i=5 Then
			ListView1.Items.Add("......")
			Exit
		End If
	Next
End Sub

Sub importTBX(path As String)
	Dim termsMap As Map
	termsMap.Initialize
	TBX.readTermsIntoMap(path,Main.currentProject.projectFile.Get("source"),Main.currentProject.projectFile.Get("target"),termsMap)
	Dim i As Int
	For Each key As String In termsMap.Keys
		
		Dim targetMap As Map
		targetMap=termsMap.Get(key)
		For Each target As String In targetMap.Keys
			Dim terminfo As Map
			terminfo=targetMap.Get(target)
			Dim tag,note,descrip As String
			If terminfo.ContainsKey("tag") Then
				tag=terminfo.Get("tag")
			End If
			If terminfo.ContainsKey("note") Then
				note=terminfo.Get("note")
			End If
			If terminfo.ContainsKey("description") Then
				descrip=terminfo.Get("description")
			End If
			i=i+1
			ListView1.Items.Add(buildTermItemText(key,target,tag,note,descrip))
			If i=5 Then
				ListView1.Items.Add("......")
				Return
			End If
		Next
	Next
End Sub

Sub buildTMItemText(source As String,target As String) As String
	Dim sb As StringBuilder
	sb.Initialize
	sb.Append("- source: ").Append(source).Append(CRLF)
	sb.Append("- target: ").Append(target)
	Return sb.ToString
End Sub

Sub buildTermItemText(source As String,target As String,tag As String,note As String,descrip As String) As String
	Dim sb As StringBuilder
	sb.Initialize
	sb.Append("- source: ").Append(source).Append(CRLF)
	sb.Append("- target: ").Append(target).Append(CRLF)
	sb.Append("- tag: ").Append(tag).Append(CRLF)
	sb.Append("- note: ").Append(note).Append(CRLF)
	sb.Append("- descrip: ").Append(descrip)
	Return sb.ToString
End Sub

Sub OkButton_MouseClicked (EventData As MouseEvent)
	result=True
	frm.Close
End Sub

Sub CancelButton_MouseClicked (EventData As MouseEvent)
	result=False
	frm.Close
End Sub
