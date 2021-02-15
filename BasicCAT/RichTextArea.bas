﻿B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=4.19
@EndOfDesignText@
#IgnoreWarnings: 12
#Event: TextChanged(Old As String, New As String)
#DesignerProperty: Key: Editable, DisplayName: Editable, FieldType: Boolean, DefaultValue: True, Description: Whether the text of the view is Editable
#DesignerProperty: Key: UseTextArea, DisplayName: UseTextArea, FieldType: Boolean, DefaultValue: False, Description: Use TextArea instead of RichTextFX
'Class module
Private Sub Class_Globals

	Private mCallBack As Object
	Private mEventName As String
	Private mForm As Form 'ignore
	Private mBase As Pane
	Private DesignerCVCalled As Boolean
	Private Initialized As Boolean 'ignore
	Private CustomViewName As String = "RichTextArea" 'Set this to the name of your custom view to provide meaningfull error logging
	Private fx As JFX
	
	'Custom View Specific Vars
	Private JO As JavaObject				'To hold the wrapped CoreArea object
	Private CustomViewNode As Node			'So that we can call B4x exposed methods on the object and don't have to use Javaobject's RunMethod for everything
	Private mBaseJO As JavaObject			'So that we can call Methods not exposed to B4x on the base pane.
	'For string matching
	Private BRACKET_PATTERN  As String
	Private SPACE_PATTERN As String
	Private offset As Int=8
	Public Font As Font
	Public Tag As Object

	Private mDefaultBorderColor As Paint
	Private mHighLightColor As Paint
	Private mLineHeightTimes As Double=0
	Public ta As TextArea
	Private mUseTextArea As Boolean=False
	Private mAutoHeight As Boolean=False
End Sub

'Initializes the object.
'For a custom view these should not be changed, if you need more parameters for a Custom view added by code, you can add them to the
'setup sub, or an additional Custom view control method
'Required for both designer and code setup. 
Public Sub Initialize (vCallBack As Object, vEventName As String)
	'CallBack Module and eventname are provided by the designer, and need to be provided if setting up in code
	'These allow callbacks to the defining module using CallSub(mCallBack,mEventname), or CallSub2 or CallSub3 to pass parameters, or CallSubDelayed....
	mCallBack = vCallBack
	mEventName = vEventName
	Font=fx.DefaultFont(15)
	mDefaultBorderColor=fx.Colors.DarkGray
	mHighLightColor=fx.Colors.RGB(135,206,235)
	If File.Exists(File.DirData("BasicCAT"),"offset") Then
		offset=File.ReadString(File.DirData("BasicCAT"),"offset")
	End If
End Sub

Public Sub DesignerCreateView(Base As Pane, Lbl As Label, Props As Map)
	'Check this is not called from setup
	If Not(Props.GetDefault("CVfromsetup",False)) Then DesignerCVCalled = True
	setUseTextArea(Props.GetDefault("UseTextArea",False))
	'Assign vars to globals
	mBase = Base
	mBase.Tag=Me
	mBase.PickOnBounds=True
	'So that we can Call Runmethod on the Base Panel to run non exposed methods
	mBaseJO = Base

	'This is passed from either the designer or setup
	mForm = Props.get("Form")


	If mUseTextArea Then
	#region event for ta
		CSSUtils.SetBorder(mBase,0,mDefaultBorderColor,3)
		Dim CJO As JavaObject = ta
		Dim O As Object = CJO.CreateEventFromUI("javafx.event.EventHandler","KeyPressed",Null)
		CJO.RunMethod("setOnKeyPressed",Array(O))
		CJO.RunMethod("setFocusTraversable",Array(True))
		Dim Obj As Reflector
		Obj.Target = ta
		Obj.AddChangeListener("taSelection", "selectionProperty")
		Dim r As Reflector
		r.Target = ta
		r.AddEventFilter("KeyPressed", "javafx.scene.input.KeyEvent.KEY_PRESSED")
	#end region
	Else
		SetDefaultBorder
		'Initialize our wrapper object
		JO.InitializeNewInstance("org.fxmisc.richtext.CodeArea",Null)
		addContextMenu
		setAutoHeight(False)
		'Cast the wrapped view to a node so we can use B4x Node methods on it.
		CustomViewNode = GetObject
		'Add the stylesheet to colour matching words to the code area node
		'JO.RunMethodJO("getStylesheets",Null).RunMethod("add",Array(File.GetUri(File.DirAssets,"richtext.css")))
	
	#region event for richtextfx
		'TextProperty Listener
		'Add an eventlistener to the ObservableValue "textProperty" so that we can get changes to the text
		Dim Event As Object = JO.CreateEvent("javafx.beans.value.ChangeListener","TextChanged","")
		JO.RunMethodJO("textProperty",Null).RunMethod("addListener",Array(Event))
	
		Dim Event As Object = JO.CreateEvent("javafx.beans.value.ChangeListener","SelectedTextChanged","")
		JO.RunMethodJO("selectedTextProperty",Null).RunMethod("addListener",Array(Event))
	
		Dim Event As Object = JO.CreateEvent("javafx.beans.value.ChangeListener","FocusChanged","")
		JO.RunMethodJO("focusedProperty",Null).RunMethod("addListener",Array(Event))
	
		Dim Event As Object = JO.CreateEvent("javafx.beans.value.ChangeListener","RedoAvailable","")
		JO.RunMethodJO("redoAvailableProperty",Null).RunMethod("addListener",Array(Event))
	
		Dim Event As Object = JO.CreateEvent("javafx.beans.value.ChangeListener","UndoAvailable","")
		JO.RunMethodJO("undoAvailableProperty",Null).RunMethod("addListener",Array(Event))
	
	
		Dim r As Reflector
		r.Target = JO
		r.AddEventFilter("Scroll", "javafx.scene.input.ScrollEvent.SCROLL")
		Dim r As Reflector
		r.Target = JO
		r.AddEventFilter("KeyPressed", "javafx.scene.input.KeyEvent.KEY_PRESSED")
	
		'BaseChanged Listener
		'Add an eventlistener to the ReadOnlyObjectProperty "layoutBoundsProperty" on the Base Pane so that we can change the internal layout to fit
		Dim Event As Object = JO.CreateEvent("javafx.beans.value.ChangeListener","BaseResized","")
		mBaseJO.RunMethodJO("layoutBoundsProperty",Null).RunMethod("addListener",Array(Event))

		Dim O As Object = JO.CreateEventFromUI("javafx.event.EventHandler","KeyPressed",Null)
		JO.RunMethod("setOnKeyPressed",Array(O))
		JO.RunMethod("setFocusTraversable",Array(True))
    #end region
	End If

	'Deal with properties we have been passed
	setEditable(Props.Get("Editable"))
	
	'Create your CustomView layout in sub CreateLayout
	CreateLayout
	
	'Other Custom Initializations
	InitializePatterns
	
	'Finally
	Initialized = True
End Sub

'Manual Setup of Custom View Pass Null to Pnl if adding to Form
Sub Setup(Form As Form,Pnl As Pane,Left As Int,Top As Int,Width As Int,Height As Int)
	'Check if DesignerCreateView has been called
	If DesignerCVCalled Then
		Log(CustomViewName & ": You should not call setup if you have defined this view in the designer")
		ExitApplication
	End If
	
	mForm = Form
	
	'Create our own base panel
	Dim Base As Pane
	Base.Initialize("")
	
	'If Null was passed, a Panel wii be created by casting, but it won't be initialized
	If Pnl.IsInitialized Then
		Pnl.AddNode(Base,Left,Top,Width,Height)
	Else
		Form.RootPane.AddNode(Base,Left,Top,Width,Height)
	End If
		
	'Set up variables to pass to DesignerCreateView so we don't have to maintain two identical subs to create the custom view
	Dim M As Map
	M.Initialize
	M.Put("Form",Form)
	M.Put("Editable",True)
	'As we are passing a map, we can use it to pass an additional flag for our own use
	'with an ID unlikely To be used by B4a In the future
	M.Put("CVfromsetup",True)
	
	'We need a label to pass to DesignerCreateView
	Dim L As Label
	L.Initialize("")
	'Default text alignment
	CSSUtils.SetStyleProperty(L,"-fx-text-alignment","center")
	'Default size for Custom View text in designer is 15
	L.Font = fx.DefaultFont(15)
	
	'Call designer create view
	DesignerCreateView(Base,L,M)
	
End Sub


'Set the initial layout for the custom view
Private Sub CreateLayout
	
	'Add the wrapper object to customview mBase
	If mUseTextArea Then
		offset=0
		mBase.AddNode(ta,offset,offset,mBase.Width-2*offset,mBase.Height-2*offset)
	Else
		mBase.AddNode(CustomViewNode,offset,offset,mBase.Width-2*offset,mBase.Height-2*offset)
	End If
    
	
	'Add any other Nodes to the CustomView
	
End Sub

'Called by a BaseChanged Listener when mBase size changes
Private Sub BaseResized_Event(MethodName As String,Args() As Object) As Object			'ignore
	
	'Make our node added to the Base Pane the same size as the Base Pane
	Dim width,height As Double
	width=mBase.Width
	height=mBase.Height
	If mUseTextArea Then
		ta.SetSize(width,height-1)
	Else
		CustomViewNode.SetSize(width-2*offset,height-2*offset)
	End If
	'Make any changes needed to other integral nodes
	UpdateLayout
End Sub

Sub Base_MouseClicked (EventData As MouseEvent)
	RequestFocus
End Sub

'Update the layout as needed when the Base Pane has changed size.
Private Sub UpdateLayout
	
End Sub

'RIGHT_TO_LEFT, LEFT_TO_RIGHT
Public Sub SetNodeOrientation(value As String)
	Dim enum1 As EnumClass
	enum1.Initialize("javafx.geometry.NodeOrientation")
	Dim taJO As JavaObject=ta
	taJO.RunMethod("setNodeOrientation",Array(enum1.ValueOf(value)))
End Sub

Public Sub SetSize(width As Double,height As Double)
	mBase.SetSize(width,height)	
	If mUseTextArea Then
		ta.SetSize(width,height-1)
	End If
End Sub

Public Sub setUseTextArea(use As Boolean)
	mUseTextArea=use
	If ta.IsInitialized=False Then
		ta.Initialize("ta")
	End If
End Sub

Public Sub getUseTextArea As Boolean
	Return mUseTextArea
End Sub

Public Sub getCaretMaxX As Double
	If mUseTextArea Then
		Dim map1 As Map
		map1=Utils.GetScreenPosition(ta)
		Return map1.Get("x")+ta.Width/10
	Else
		Dim optional As JavaObject=getCaretBounds
		Dim boundingbox As JavaObject=optional.RunMethod("get",Null)
		Return boundingbox.RunMethod("getMaxX",Null)
	End If

End Sub

Public Sub getCaretMaxY As Double
	If mUseTextArea Then
		Dim map1 As Map
		map1=Utils.GetScreenPosition(ta)
		Return map1.Get("y")+ta.Height
	Else
		Dim optional As JavaObject=getCaretBounds
		Dim boundingbox As JavaObject=optional.RunMethod("get",Null)
		Return boundingbox.RunMethod("getMaxY",Null)
	End If
End Sub

Private Sub getCaretBounds As JavaObject
	Return JO.RunMethod("getCaretBounds",Null)
End Sub

Public Sub getLeft As Double
	Return mBase.Left
End Sub

Public Sub setLeft(left As Double)
	mBase.Left=left
End Sub

Public Sub getTop As Double
	Return mBase.Top
End Sub

Public Sub setTop(Top As Double)
	mBase.Top=Top
End Sub

Sub setEnabled(enabled As Boolean)
	mBase.Enabled=enabled
	If mUseTextArea=False Then
		If enabled=False Then
			CustomViewNode.Alpha=0.5
			'CSSUtils.SetBackgroundColor(CustomViewNode,fx.Colors.DarkGray)
		Else
			CustomViewNode.Alpha=1.0
		End If
	End If
End Sub

Sub setLineHeightTimes(times As Double)
	mLineHeightTimes=times
End Sub

Sub getBasePane As Pane
	Return mBase
End Sub

Sub getHeight As Double
	Return mBase.Height
End Sub

Sub setHeight(height As Double)
	mBase.PrefHeight=height
End Sub

Sub getWidth As Double
	Return mBase.width
End Sub

Sub setWidth(width As Double)
	mBase.PrefWidth=width
End Sub

Sub getParent As Node
	Return mBase.Parent
End Sub

Sub getSelectionStart As Double
	If mUseTextArea Then
		Return ta.SelectionStart
	Else
		Return getSelection(0)
	End If

End Sub

Sub getSelectionEnd As Double
	If mUseTextArea Then
		Return ta.SelectionEnd
	Else
		Return getSelection(1)
	End If
End Sub

Sub setSelection(startIndex As Int,endIndex As Int)
	If mUseTextArea Then
		ta.SetSelection(startIndex,endIndex)
	Else
		JO.RunMethod("selectRange",Array(startIndex,endIndex))
	End If
End Sub

Sub RequestFocus
	If mUseTextArea Then
		ta.RequestFocus
	Else
		JO.RunMethod("requestFocus",Null)
	End If
End Sub

Sub setWrapText(wrap As Boolean)
	If mUseTextArea Then
		ta.WrapText=wrap
	Else
		JO.RunMethod("setWrapText",Array(wrap))
	End If
End Sub

#region border
Public Sub resetBorderColor
	mDefaultBorderColor=fx.Colors.DarkGray
End Sub

Public Sub setDefaultBorderColor(color As Paint)
	mDefaultBorderColor=color
	SetDefaultBorder
End Sub

Public Sub getDefaultBorderColor As Paint
	Return mDefaultBorderColor
End Sub

Public Sub SetDefaultBorder
	Dim width As Double
	If mDefaultBorderColor<>fx.Colors.DarkGray Then
		width=3
	Else
		width=0.5
	End If
	CSSUtils.SetBorder(mBase,width,mDefaultBorderColor,3)
	'CSSUtils.SetStyleProperty(mBase,"-fx-effect","null")
End Sub

Public Sub SetBorderInHighlight(color As Paint)
	CSSUtils.SetBorder(mBase,3,color,3)
	'CSSUtils.SetStyleProperty(mBase,"-fx-effect","dropshadow(gaussian, skyblue , 3, 1, 0, 0)")
End Sub

Sub AdjustBorder(hasFocus As Boolean)
	If hasFocus Then
		SetBorderInHighlight(mHighLightColor)
	Else
		SetDefaultBorder
	End If
End Sub

Public Sub setHighLightColor(color As Paint)
	mHighLightColor=color
End Sub

Public Sub getHighLightColor As Paint
	Return mHighLightColor
End Sub
#end region

Sub FocusChanged_Event (MethodName As String,Args() As Object) As Object							'ignore
	Dim hasFocus As Boolean=Args(2)
	If SubExists(mCallBack,mEventName & "_FocusChanged") Then
		CallSubDelayed2(mCallBack,mEventName & "_FocusChanged",hasFocus)
	End If
	CallSubDelayed2(Me,"AdjustBorder",hasFocus)
End Sub

Sub ta_FocusChanged (HasFocus As Boolean)
	If SubExists(mCallBack,mEventName & "_FocusChanged") Then
		CallSubDelayed2(mCallBack,mEventName & "_FocusChanged",HasFocus)
	End If
End Sub

Sub KeyPressed_Event (MethodName As String, Args() As Object) As Object 'ignore
	Dim KEvt As JavaObject = Args(0)
	Dim result As String
	result=KEvt.RunMethod("getCode",Null)
	If SubExists(mCallBack,mEventName & "_KeyPressed") Then
		CallSubDelayed2(mCallBack,mEventName & "_KeyPressed",result)
	End If
End Sub

private Sub getSelection As Int()
	Dim indexRange As String=JO.RunMethodJO("getSelection",Null).RunMethod("toString",Null)
	Dim selectionStart,selectionEnd As Int
	selectionStart=Regex.Split(",",indexRange)(0)
	selectionEnd=Regex.Split(",",indexRange)(1)
	Return Array As Int(selectionStart,selectionEnd)
End Sub

'Convenient method to assign a single style class.
Public Sub SetStyleClass(SetFrom As Int, SetTo As Int, Class As String)
	JO.RunMethod("setStyleClass",Array As Object(SetFrom, SetTo, Class))
End Sub

'Gets the value of the property length.
Public Sub Length As Int
	If mUseTextArea Then
		Return ta.Text.Length
	Else
		Return JO.RunMethod("getLength",Null)
	End If
End Sub

Public Sub getText As String
	If mUseTextArea Then
		Return ta.Text
	Else
		Return JO.RunMethod("getText",Null)
	End If
End Sub

Public Sub setText(str As String)
	If mUseTextArea Then
		ta.Text=str
	Else
		JO.RunMethod("replaceText",Array As Object(0, Length, str))
		updateStyleSpans
	End If
End Sub

'Replaces a range of characters with the given text.
Public Sub ReplaceText(Start As Int, ThisEnd As Int, str As String)
	JO.RunMethod("replaceText",Array As Object(Start, ThisEnd, str))
	updateStyleSpans
End Sub

'Get/Set the CodeArea Editable
Public Sub setEditable(Editable As Boolean)
	If mUseTextArea Then
		ta.Editable=Editable
	Else
		JO.RunMethod("setEditable",Array(Editable))
	End If
End Sub

Public Sub getEditable As Boolean
	If mUseTextArea Then
		Return ta.Editable
	Else
		Return JO.RunMethod("isEditable",Null)
	End If
	
End Sub

'Get the unwrapped object
Public Sub GetObject As Object
	Return JO
End Sub

'Get the unwrapped object As a JavaObject
Public Sub GetObjectJO As JavaObject
	Return JO
End Sub
'Comment if not needed

'Set the underlying Object, must be of correct type
Public Sub SetObject(Obj As Object)
	JO = Obj
End Sub

Public Sub LineHeight(widthOffset As Int) As Double
	Return Utils.MeasureMultilineTextHeight(Font,mBase.Width-2*offset-widthOffset,"a")
End Sub

Public Sub setAutoHeight(value As Boolean)
	If mUseTextArea=False Then
		JO.RunMethod("setAutoHeight",Array(value))
		mAutoHeight=value
	End If
End Sub

Public Sub AreaHeight As Double
	If mUseTextArea Then
		Return ta.Height
	Else
		Dim height As Double
		Try
			height=JO.RunMethod("getTotalHeightEstimate",Null)
		Catch
			height=JO.RunMethod("getHeight",Null)
		End Try
		Return height
	End If
End Sub


Public Sub totalHeight As Double
	Dim height As Double=20
	If mUseTextArea Then
		height=Max(height,Utils.MeasureMultilineTextHeight(Font,mBase.Width-2*offset-20,getText))
		height=height+Max(mLineHeightTimes,1.5)*LineHeight(20)
	Else
		Return AreaHeight+2*offset
	End If
	Return height
End Sub

Sub setFontFamily(name As String)
	If mUseTextArea=False Then
		CSSUtils.SetStyleProperty(JO,"-fx-font-family",name)
	End If
	Font=fx.CreateFont(name,Font.Size,False,False)
End Sub

Sub setFontSzie(pixel As Int)
	If mUseTextArea=False Then
		CSSUtils.SetStyleProperty(JO,"-fx-font-size",pixel&"px")
	End If
	Font=fx.CreateFont(Font.FamilyName,pixel,False,False)
End Sub

'Callback from TextProperty Listener when the codearea text changes
Sub TextChanged_Event(MethodName As String,Args() As Object) As ResumableSub							'ignore
	updateStyleSpans
	'Sleep(50)
	'mBase.SetSize(mBase.Width,AreaHeight+2*offset)
	If SubExists(mCallBack,mEventName & "_TextChanged") Then
		CallSubDelayed3(mCallBack,mEventName & "_TextChanged",Args(1),Args(2))
	End If
End Sub

Sub ta_TextChanged (Old As String, New As String)
	If SubExists(mCallBack,mEventName & "_TextChanged") Then
		CallSubDelayed3(mCallBack,mEventName & "_TextChanged",Old,New)
	End If
End Sub

Sub updateStyleSpans
	JO.RunMethod("setStyleSpans",Array(0,ComputeHighlightingB4x(getText)))
End Sub

Sub SelectedTextChanged_Event(MethodName As String,Args() As Object) As Object							'ignore
	If SubExists(mCallBack,mEventName & "_SelectedTextChanged") Then
		CallSubDelayed3(mCallBack,mEventName & "_SelectedTextChanged",Args(1),Args(2))
	End If
	updateContextMenuBasedOnSelection(Args(2))
End Sub

Sub taSelection_changed(old As Object, new As Object)
	Dim selected As String=ta.Text.SubString2(ta.SelectionStart,ta.SelectionEnd)
	If SubExists(mCallBack,mEventName & "_SelectedTextChanged") Then
		CallSubDelayed3(mCallBack,mEventName & "_SelectedTextChanged","",selected)
	End If
End Sub

'Setup for pattern matching
Sub InitializePatterns
	BRACKET_PATTERN="<.*?>"
	SPACE_PATTERN = " *"
End Sub

'Create the style types for matching words
Sub ComputeHighlightingB4x(str As String) As JavaObject

	'Dim PMatcher As PatternMatcher = Pattern1.Matcher(Text)
	Dim Matcher As Matcher = Regex.Matcher($"(?<BRACKET>${BRACKET_PATTERN})|(?<SPACE>${SPACE_PATTERN})"$,str)
	Dim MJO As JavaObject = Matcher
	
	Dim SpansBuilder As JavaObject
	SpansBuilder.InitializeNewInstance("org.fxmisc.richtext.model.StyleSpansBuilder",Null)
	
	Dim Collections As JavaObject
	Collections.InitializeStatic("java.util.Collections")
	
	Dim LastKwEnd As Int = 0
	Dim StyleClass As String
	Dim Index As Int
	Do While Matcher.Find
		StyleClass = ""
		If Matcher.Group(2) <> Null Then
			Index = 2
			StyleClass = "space"
		Else
			If Matcher.Group(1) <> Null Then
				Index = 1
				StyleClass = "bracket"
			End If
		End If
		Dim StrLength As Int = Matcher.GetStart(Index) - LastKwEnd
		SpansBuilder.RunMethod("add",Array(Collections.RunMethod("emptyList",Null),StrLength))
		StrLength = MJO.RunMethod("end",Null) - Matcher.GetStart(Index)
		SpansBuilder.RunMethod("add",Array(Collections.RunMethod("singleton",Array(StyleClass)),StrLength))
		LastKwEnd = Matcher.GetEnd(Index)
	Loop
	SpansBuilder.RunMethod("add",Array(Collections.RunMethod("emptyList",Null),str.Length - LastKwEnd))
	Return SpansBuilder.RunMethod("create",Null)
End Sub

Sub Scroll_Filter (EventData As Event)
	If mBase.Height>AreaHeight-2*offset Then
		Dim e As JavaObject = EventData
		Dim Parent As Node
		Parent=mBase.Parent
		Dim ParentJO As JavaObject=Parent
		Dim event As Object=e.RunMethod("copyFor",Array(e.RunMethod("getSource",Null),Parent))
		ParentJO.RunMethod("fireEvent",Array(event))
		EventData.Consume
	End If
End Sub

Sub KeyPressed_Filter (EventData As Event)
	Dim e As JavaObject = EventData
	Dim code As String = e.RunMethod("getCode", Null)
	If code = "ENTER" Then
		If SubExists(mCallBack,mEventName & "_KeyPressed") Then
			CallSubDelayed2(mCallBack,mEventName & "_KeyPressed",code)
		End If
		EventData.Consume
	End If
End Sub

Sub UndoAvailable_Event(MethodName As String,Args() As Object) As Object							'ignore
	updateContextMenuInTermsofUndoRedo
End Sub

Sub RedoAvailable_Event(MethodName As String,Args() As Object) As Object							'ignore
	updateContextMenuInTermsofUndoRedo
End Sub

Sub addContextMenu
	Dim cm As ContextMenu
	cm.Initialize("cm")
	Dim style As String=$"-fx-font-size:16px;-fx-font-family:"serif";"$
	For Each text As String In Array("Cut","Copy","Paste","Undo","Redo","Select all")
		Dim mi As MenuItem
		mi.Initialize(text,"mi")
		Dim miJO As JavaObject=mi
		miJO.RunMethod("setStyle",Array(style))
		cm.MenuItems.Add(mi)
	Next
	JO.RunMethod("setContextMenu",Array(cm))
	updateContextMenuBasedOnSelection("")
	updateContextMenuInTermsofUndoRedo
End Sub

Sub updateContextMenuBasedOnSelection(new As String)
	Dim cm As ContextMenu=JO.RunMethod("getContextMenu",Null)
	For Each mi As MenuItem In cm.MenuItems
		If mi.Text="Copy" Or mi.Text="Cut" Then
			If new="" Then
				mi.Enabled=False
			Else
				mi.Enabled=True
			End If
		End If
	Next
End Sub

Sub updateContextMenuInTermsofUndoRedo
	Dim cm As ContextMenu=JO.RunMethod("getContextMenu",Null)
	For Each mi As MenuItem In cm.MenuItems
		Select mi.Text
			Case "Undo"
				If JO.RunMethod("isUndoAvailable",Null) Then
					mi.Enabled=True
				Else
					mi.Enabled=False
				End If
			Case "Redo"
				If JO.RunMethod("isRedoAvailable",Null) Then
					mi.Enabled=True
				Else
					mi.Enabled=False
				End If
		End Select
	Next
End Sub


Sub mi_Action
	Dim mi As MenuItem=Sender
	Select mi.Text
		Case "Copy"
			JO.RunMethod("copy",Null)
		Case "Cut"
			JO.RunMethod("cut",Null)
		Case "Paste"
			JO.RunMethod("paste",Null)
		Case "Select all"
			setSelection(0,getText.Length)
		Case "Undo"
			JO.RunMethod("undo",Null)
		Case "Redo"
			JO.RunMethod("redo",Null)
	End Select
End Sub

