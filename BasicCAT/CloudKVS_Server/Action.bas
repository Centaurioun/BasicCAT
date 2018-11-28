﻿B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=4.19
@EndOfDesignText@
'Handler class
Sub Class_Globals
	Private serializator As B4XSerializator
End Sub

Public Sub Initialize
	
End Sub

Sub Handle(req As ServletRequest, resp As ServletResponse)
	Dim task As Task = serializator.ConvertBytesToObject(Bit.InputStreamToBytes(req.InputStream))
	Log($"Task: ${task.TaskName}, User: ${task.TaskItem.UserField}, Key: ${task.TaskItem.KeyField}, IP: ${req.RemoteAddress}"$)
	If task.TaskName.StartsWith("getuser") Then
		'the lastid value is stored in the key field
		Dim items As List = DB.GetUserItems(task.TaskItem.UserField, task.TaskItem.KeyField)
		Dim bytes() As Byte = serializator.ConvertObjectToBytes(items)
		resp.OutputStream.WriteBytes(bytes, 0, bytes.Length)
	Else If task.TaskName = "additem" Then
		DB.AddItem(task.TaskItem)
	End If
End Sub