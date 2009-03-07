Attribute VB_Name = "modScripting"
'/* Scripting.bas
' * ~~~~~~~~~~~~~~~~
' * StealthBot VBScript support module
' * ~~~~~~~~~~~~~~~~
' * Modified by Swent 11/06/2007
' */
Option Explicit

Public Type scObj
    SCModule As Module
    ObjName  As String
    ObjType  As String
    obj      As Object
End Type

Public VetoNextMessage   As Boolean
Public boolOverride      As Boolean

Private m_arrObjs()      As scObj
Private m_objCount       As Integer

Public Sub InitScriptControl(ByRef SC As ScriptControl)

    ' ...
    DestroyObjs
    SC.Reset
    
    ' ...
    If (ReadINI("Other", "ScriptAllowUI", GetConfigFilePath()) <> "N") Then
        SC.AllowUI = True
    End If

    '// Create scripting objects
    SC.AddObject "ssc", SharedScriptSupport, True
    SC.AddObject "scTimer", frmChat.scTimer
    SC.AddObject "scINet", frmChat.INet
    SC.AddObject "BotVars", BotVars

End Sub

Public Sub LoadScripts(ByRef SC As ScriptControl)

    ' ...
    On Error GoTo ERROR_HANDLER

    Dim CurrentModule As Module

    Dim strPath  As String  ' ...
    Dim filename As String  ' ...
    Dim fileExt  As String  ' ...
    Dim i        As Integer ' ...
    
    ' ********************************
    '      LOAD REGULAR SCRIPTS
    ' ********************************

    ' ...
    strPath = App.Path & "\scripts\"
    
    ' ...
    If (Dir(strPath) <> vbNullString) Then
        ' ...
        filename = Dir(strPath)
        
        ' ...
        Do While (filename <> vbNullString)
            ' ...
            If (IsValidFileExtension(GetFileExtension(filename))) Then
                ' ...
                Set CurrentModule = SC.Modules.Add(filename)
                
                ' ...
                FileToModule CurrentModule, strPath & filename
            End If
            
            ' ...
            filename = Dir()
        Loop
    End If
    
    ' ********************************
    '      LOAD PLUGIN SYSTEM
    ' ********************************

    ' ...
    If (ReadINI("Override", "DisablePS", GetConfigFilePath()) <> "Y") Then
        ' ...
        boolOverride = False
    
        ' ...
        strPath = GetFilePath("PluginSystem.dat")
        
        ' ...
        If (LenB(Dir$(strPath)) = 0) Then
            Call frmChat.AddChat(vbRed, "Cannot find PluginSystem.dat. It must exist in order to load plugins!")
            Call frmChat.AddChat(vbYellow, "You may download PluginSystem.dat to your StealthBot folder using the link below.")
            Call frmChat.AddChat(vbWhite, "http://www.stealthbot.net/p/Users/Swent/index.php?file=PluginSystem.dat")
        Else
            FileToModule SC.Modules(1), strPath
        End If
    Else
        boolOverride = True
    End If
        
    ' ...
    Exit Sub

' ...
ERROR_HANDLER:

    ' ...
    frmChat.AddChat vbRed, "Error: " & Err.description & " in LoadScripts()."

    ' ...
    Exit Sub

End Sub

Private Function FileToModule(ByRef ScriptModule As Module, ByVal filePath As String)

    On Error GoTo ERROR_HANDLER

    Dim strLine          As String  ' ...
    Dim strContent       As String  ' ...
    Dim f                As Integer ' ...
    Dim blnCheckOperands As Boolean
    
    ' ...
    f = FreeFile
    
    ' ...
    blnCheckOperands = True

    ' ...
    Open filePath For Input As #f
        ' ...
        Do While (EOF(f) = False)
            ' ...
            Line Input #f, strLine
            
            ' ...
            strLine = Trim(strLine)
            
            ' ...
            If (Len(strLine) >= 1) Then
                If ((blnCheckOperands) And (Left$(strLine, 1) = "#")) Then
                    If (InStr(1, strLine, " ") <> 0) Then
                        Dim strCommand As String ' ...
                    
                        strCommand = _
                            LCase$(Mid$(strLine, 2, InStr(1, strLine, " ") - 2))

                        If (strCommand = "include") Then
                            If (Len(LCase$(strLine)) >= 12) Then
                                Dim tmp As String ' ...
                                
                                ' ...
                                tmp = _
                                    LCase$(Mid$(strLine, 11, Len(strLine) - 11))
                                
                                ' ...
                                If (Left$(tmp, 1) = "\") Then
                                    filePath = App.Path & "\scripts\" & tmp
                                Else
                                    filePath = tmp
                                End If
        
                                ' ...
                                FileToModule ScriptModule, filePath
                            End If
                        End If
                    End If
                Else
                    ' ...
                    strContent = strContent & strLine & vbCrLf
                    
                    ' ...
                    blnCheckOperands = False
                End If
            End If
            
            ' ...
            strLine = vbNullString
        Loop
    Close #f
    
    ' ...
    CreateDefautModuleProcs ScriptModule

    ' ...
    ScriptModule.AddCode strContent
    
    Exit Function
    
ERROR_HANDLER:

    frmChat.AddChat vbRed, _
        "Error (#" & Err.Number & "): " & Err.description & " in FileToModule()."
        
    Exit Function

End Function

Private Sub CreateDefautModuleProcs(ByRef ScriptModule As Module)

    Dim str As String ' storage buffer for module code
    
    ' GetModuleName() module-level function
    str = str & "Function GetModuleName()" & vbNewLine
    str = str & "   GetModuleName = " & Chr$(34) & ScriptModule.Name & Chr$(34) & vbNewLine
    str = str & "End Function" & vbNewLine
    
    ' Me() module-level function
    str = str & "Function ScriptObj()" & vbNewLine
    str = str & "   Set ScriptObj = GetScriptObjByName(GetModuleName())" & vbNewLine
    str = str & "End Function" & vbNewLine
    
    ' CreateObj() module-level function
    str = str & "Function CreateObj(ObjType, ObjName)" & vbNewLine
    str = str & "   Set CreateObj = _ " & vbNewLine
    str = str & "         CreateObjEx(GetModuleName(), ObjType, ObjName)" & vbNewLine
    str = str & "End Function" & vbNewLine
    
    ' DeleteObj() module-level function
    str = str & "Sub DeleteObj(ObjType, ObjName)" & vbNewLine
    str = str & "   Call DeleteObjEx(GetModuleName(), ObjType, ObjName)" & vbNewLine
    str = str & "End Sub" & vbNewLine
    
    ' GetObjByName() module-level function
    str = str & "Function GetObjByName(ObjType, ObjName)" & vbNewLine
    str = str & "   Set GetObjByName = _ " & vbNewLine
    str = str & "         GetObjByNameEx(GetModuleName(), ObjType, ObjName)" & vbNewLine
    str = str & "End Function" & vbNewLine

    ' store module-level coding
    ScriptModule.AddCode str
    
End Sub

Private Function GetFileExtension(ByVal filename As String)

    On Error Resume Next

    ' ...
    If (InStr(1, filename, ".") <> 0) Then
        GetFileExtension = _
            Mid$(filename, InStr(1, filename, ".") + 1)
    End If

End Function

Private Function IsValidFileExtension(ByVal ext As String) As Boolean

    Dim exts() As String  ' ...
    Dim i      As Integer ' ...

    ' ...
    ReDim exts(0 To 2)
    
    ' ...
    exts(0) = "dat"
    exts(1) = "txt"
    exts(2) = "vbs"
    
    ' ...
    For i = 0 To UBound(exts) - 1
        If (StrComp(ext, exts(i), vbTextCompare) = 0) Then
            IsValidFileExtension = True
            
            Exit Function
        End If
    Next i
    
    IsValidFileExtension = False

End Function

Public Function InitScripts()

    Dim i As Integer ' ...

    ' ...
    RunInAll "Event_Load"

    ' ...
    If (g_Online) Then
        RunInAll "Event_LoggedOn", GetCurrentUsername, BotVars.Product
        RunInAll "Event_ChannelJoin", g_Channel.Name, g_Channel.Flags

        If (g_Channel.Users.Count > 0) Then
            For i = 1 To g_Channel.Users.Count
                With g_Channel.Users(i)
                     RunInAll "Event_UserInChannel", .DisplayName, .Flags, .Stats.ToString, .Ping, _
                        .game, False
                End With
             Next i
         End If
    End If

End Function

Public Sub RunInAll(ParamArray Parameters() As Variant)

    On Error GoTo ERROR_HANDLER

    Dim SC    As ScriptControl
    Dim i     As Integer ' ...
    Dim arr() As Variant ' ...
    
    ' ...
    Set SC = frmChat.SControl
    
    ' ...
    arr() = Parameters()

    ' ...
    For i = 1 To SC.Modules.Count
        CallByNameEx SC.Modules(i), "Run", VbMethod, arr()
    Next

    Exit Sub
    
ERROR_HANDLER:
    ' object does not support property or method
    If (Err.Number = 438) Then
        Resume Next
    End If

    frmChat.AddChat vbRed, "Error (#" & Err.Number & "): " & Err.description & _
        " in RunInAll()."
    
    Exit Sub
    
End Sub

Public Function CallByNameEx(obj As Object, ProcName As String, CallType As VbCallType, Optional vArgsArray _
    As Variant)
    
    On Error GoTo ERROR_HANDLER
    
    Dim oTLI    As TLI.TLIApplication
    Dim ProcID  As Long
    Dim numArgs As Long
    Dim i       As Long
    Dim v()     As Variant
    
    Set oTLI = New TLIApplication

    ProcID = oTLI.InvokeID(obj, ProcName)

    If (IsMissing(vArgsArray)) Then
        CallByNameEx = oTLI.InvokeHook(obj, ProcID, CallType)
    End If
    
    If (IsArray(vArgsArray)) Then
        numArgs = UBound(vArgsArray)
        
        ReDim v(numArgs)
        
        For i = 0 To numArgs
            v(i) = vArgsArray(numArgs - i)
        Next i
        
        CallByNameEx = oTLI.InvokeHookArray(obj, ProcID, CallType, v)
    End If
    
    Set oTLI = Nothing
    
    Exit Function

ERROR_HANDLER:
    ' ...
    If (frmChat.SControl.Error) Then
        Exit Function
    End If

    frmChat.AddChat vbRed, "Error (#" & Err.Number & "): " & Err.description & _
        " in CallByNameEx()."
        
    Set oTLI = Nothing
        
    Exit Function
    
End Function

Public Function Objects(objIndex As Integer) As scObj

    Objects = m_arrObjs(objIndex)

End Function

Public Function ObjCount(Optional ObjType As String) As Integer
    
    Dim i As Integer ' ...

    If (ObjType <> vbNullString) Then
        For i = 0 To m_objCount - 1
            If (StrComp(ObjType, m_arrObjs(i).ObjType, vbTextCompare) = 0) Then
                ObjCount = (ObjCount + 1)
            End If
        Next i
    Else
        ObjCount = m_objCount
    End If

End Function

Public Function CreateObjEx(ByRef SCModule As Module, ByVal ObjType As String, ByVal ObjName As String) As Object

    Dim obj As scObj ' ...
    
    ' redefine array size & check for duplicate controls
    If (m_objCount) Then
        Dim i As Integer ' loop counter variable

        For i = 0 To m_objCount - 1
            If (m_arrObjs(i).SCModule.Name = SCModule.Name) Then
                If (StrComp(m_arrObjs(i).ObjType, ObjType, vbTextCompare) = 0) Then
                    If (StrComp(m_arrObjs(i).ObjName, ObjName, vbTextCompare) = 0) Then
                        Exit Function
                    End If
                End If
            End If
        Next i
        
        ReDim Preserve m_arrObjs(0 To m_objCount)
    Else
        ReDim m_arrObjs(0)
    End If

    ' store our module name & type
    obj.ObjName = ObjName
    obj.ObjType = ObjType

    ' store our module handle
    Set obj.SCModule = SCModule
    
    ' grab/create instance of object
    Select Case (UCase$(ObjType))
        Case "TIMER"
            If (ObjCount(ObjType) > 0) Then
                Load frmChat.tmrScript(ObjCount(ObjType))
            End If
            
            Set obj.obj = _
                    frmChat.tmrScript(ObjCount(ObjType))
                    
        'Case "HighResTimer"
        '    If (ObjCount(ObjType) > 0) Then
        '        Load frmChat.tmrScriptHR(ObjCount(ObjType))
        '    End If
        '
        '    Set obj.obj = _
        '            frmChat.tmrScriptHR(ObjCount(ObjType))
            
        Case "WINSOCK"
            If (ObjCount(ObjType) > 0) Then
                Load frmChat.sckScript(ObjCount(ObjType))
            End If
            
            Set obj.obj = _
                    frmChat.sckScript(ObjCount(ObjType))
        
        Case "INET"
            If (ObjCount(ObjType) > 0) Then
                Load frmChat.itcScript(ObjCount(ObjType))
            End If
            
            Set obj.obj = _
                    frmChat.itcScript(ObjCount(ObjType))
        
        Case "FORM"
            Set obj.obj = New frmScript
            
            ' ...
            obj.obj.setName ObjName
            obj.obj.setSCModule SCModule
            
        ' i don't menus are going to work :|
        'Case "MENU"
        '    If (ObjCount(ObjType) > 0) Then
        '        Load frmChat.mnuScript(ObjCount(ObjType))
        '    End If
        '
        '    Set obj.obj = _
        '            frmChat.mnuScript(ObjCount(ObjType))
            
    End Select

    ' store object
    m_arrObjs(m_objCount) = obj
    
    ' increment object counter
    m_objCount = (m_objCount + 1)
    
    ' create class variable for object
    SCModule.ExecuteStatement "Set " & ObjName & " = GetObjByName(" & _
        Chr$(34) & ObjType & Chr$(34) & ", " & Chr$(34) & ObjName & Chr$(34) & ")"

    ' return object
    Set CreateObjEx = obj.obj

End Function

Public Sub DeleteObjEx(ByRef SCModule As Module, ByVal TimerName As String)

    
End Sub

Public Function GetObjByNameEx(ByRef SCModule As Module, ByVal ObjType As String, ByVal ObjName As String) As Object

    Dim i As Integer ' ...
    
    ' ...
    For i = 0 To m_objCount - 1
        If (m_arrObjs(i).SCModule.Name = SCModule.Name) Then
            If (StrComp(m_arrObjs(i).ObjType, ObjType, vbTextCompare) = 0) Then
                If (StrComp(m_arrObjs(i).ObjName, ObjName, vbTextCompare) = 0) Then
                    Set GetObjByNameEx = m_arrObjs(i).obj
    
                    Exit Function
                End If
            End If
        End If
    Next i

End Function

Public Function GetSCObjByIndexEx(ByVal ObjType As String, ByVal Index As Integer) As scObj

    Dim i As Integer ' ...

    For i = 0 To ObjCount() - 1
        If (StrComp(ObjType, Objects(i).ObjType, vbTextCompare) = 0) Then
            If (m_arrObjs(i).obj.Index = Index) Then
                GetSCObjByIndexEx = m_arrObjs(i)
                
                Exit For
            End If
        End If
    Next i

End Function

Private Sub DestroyObjs()

    On Error GoTo ERROR_HANDLER

    Dim i As Integer ' ...
    
    ' ...
    For i = m_objCount - 1 To 0 Step -1
        ' ...
        Select Case (UCase$(m_arrObjs(i).ObjType))
            Case "TIMER"
                If (m_arrObjs(i).obj.Index > 0) Then
                    Unload frmChat.tmrScript(m_arrObjs(i).obj.Index)
                Else
                    frmChat.tmrScript(0).Enabled = False
                End If
                
            Case "WINSOCK"
                If (m_arrObjs(i).obj.Index > 0) Then
                    Unload frmChat.sckScript(m_arrObjs(i).obj.Index)
                Else
                    frmChat.sckScript(0).Close
                End If
                
            Case "INET"
                If (m_arrObjs(i).obj.Index > 0) Then
                    Unload frmChat.itcScript(m_arrObjs(i).obj.Index)
                Else
                    frmChat.itcScript(0).Cancel
                End If
                
            Case "FORM"
                Unload m_arrObjs(i).obj
                
        End Select

        ' ...
        Set m_arrObjs(i).obj = Nothing
    Next i
    
    m_objCount = 0
    
    ReDim m_arrObjs(m_objCount)
    
    Exit Sub
    
ERROR_HANDLER:
    
    frmChat.AddChat vbRed, _
        "Error (#" & Err.Number & "): " & Err.description & " in DestroyObjs()."
        
    Resume Next
    
End Sub

Public Sub SetVeto(ByVal B As Boolean)

    VetoNextMessage = B
    
End Sub

Public Function GetVeto() As Boolean

    GetVeto = VetoNextMessage
    
    VetoNextMessage = False
    
End Function
