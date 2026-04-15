#tag Module
' Authors: Bina Cohen: 207562901 & Hodaya Levinstein: 213803729
Begin Module T0VMWarmup
	#tag Property, Flags = &h21
		Private mOut As TextOutputStream
	#tag EndProperty
	
	#tag Property, Flags = &h21
		Private mCurrentVmBaseName As String
	#tag EndProperty
	
	#tag Property, Flags = &h21
		Private mLogicCounter As Integer
	#tag EndProperty
	
	#tag Method, Flags = &h0
		Sub RunInteractive()
			Stdout.Write("Enter input directory path: ")
			Var path As String = Stdin.ReadLine
			RunWithPath(path)
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h0
		Sub RunWithPath(path As String)
			Var inputItem As FolderItem = GetFolderItem(path, FolderItem.PathTypeNative)
			
			If inputItem Is Nil Or Not inputItem.Exists Then
				Stdout.WriteLine("Invalid path: " + path)
				Return
			End If
			
			Var vmFiles() As FolderItem
			Var outputFile As FolderItem
			
			If inputItem.IsFolder Then
				Var dir As FolderItem = inputItem
				outputFile = dir.Child(dir.Name + ".asm")
				
				For i As Integer = 1 To dir.Count
					Var item As FolderItem = dir.Item(i)
					If item Is Nil Then Continue
					If Not item.Exists Then Continue
					If item.IsFolder Then Continue
					
					If item.Extension.Lowercase = "vm" Then
						vmFiles.Add(item)
					End If
				Next
				
				vmFiles.Sort(AddressOf CompareFolderItemByName)
			Else
				If inputItem.Extension.Lowercase <> "vm" Then
					Stdout.WriteLine("Invalid VM file: " + inputItem.Name)
					Return
				End If
				
				Var parentDir As FolderItem = inputItem.Parent
				If parentDir Is Nil Then
					Stdout.WriteLine("Invalid VM file path: " + inputItem.Name)
					Return
				End If
				
				outputFile = parentDir.Child(BaseNameWithoutExtension(inputItem) + ".asm")
				vmFiles.Add(inputItem)
			End If
			
			If vmFiles.Count = 0 Then
				Stdout.WriteLine("No .vm files found in: " + inputItem.Name)
				Return
			End If
			
			mOut = TextOutputStream.Create(outputFile)
			
			For Each vmFile As FolderItem In vmFiles
				ProcessVmFile(vmFile)
			Next
			
			mOut.Close
			mOut = Nil
			
			Stdout.WriteLine("Output file is ready: " + outputFile.Name)
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub ProcessVmFile(vmFile As FolderItem)
			' Counter is per input file (logical commands only)
			mLogicCounter = 1
			
			' Store current VM file name WITHOUT extension (required by spec)
			mCurrentVmBaseName = SanitizeSymbolPart(BaseNameWithoutExtension(vmFile))
			
			Var input As TextInputStream = TextInputStream.Open(vmFile)
			
			While Not input.EndOfFile
				Var line As String = input.ReadLine
				line = CleanLine(line)
				If line = "" Then Continue
				
				Var tokens() As String = Tokenize(line)
				If tokens.Count = 0 Then Continue
				
				Var cmd As String = tokens(0).Lowercase
				
				Select Case cmd
				Case "add"
					HandleAdd
				Case "sub"
					HandleSub
				Case "neg"
					HandleNeg
				
				Case "and"
					HandleAnd
				Case "or"
					HandleOr
				Case "not"
					HandleNot
				
				Case "eq"
					HandleEq
				Case "gt"
					HandleGt
				Case "lt"
					HandleLt
				
				Case "push"
					If tokens.Count >= 3 Then
						Var segment As String = tokens(1)
						Var index As Integer = CType(Val(tokens(2)), Integer)
						HandlePush(segment, index)
					End If
				
				Case "pop"
					If tokens.Count >= 3 Then
						Var segment As String = tokens(1)
						Var index As Integer = CType(Val(tokens(2)), Integer)
						HandlePop(segment, index)
					End If
				
				Else
					' Input is assumed valid per assignment; ignore unknown lines.
				End Select
			Wend
			
			input.Close
			
			Stdout.WriteLine("End of input file: " + vmFile.Name)
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Function CleanLine(line As String) As String
			' Strips optional inline comments and trims whitespace.
			Var s As String = line
			Var p As Integer = s.IndexOf("//")
			If p >= 0 Then
				s = s.Left(p)
			End If
			Return s.Trim
		End Function
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Function Tokenize(line As String) As String()
			Var normalized As String = line.ReplaceAll(Chr(9), " ")
			Var raw() As String = normalized.Split(" ")
			
			Var tokens() As String
			For Each part As String In raw
				Var t As String = part.Trim
				If t <> "" Then
					tokens.Add(t)
				End If
			Next
			
			Return tokens
		End Function
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Function BaseNameWithoutExtension(f As FolderItem) As String
			Var name As String = f.Name
			
			If name.Length >= 3 Then
				Var lower As String = name.Lowercase
				If lower.EndsWith(".vm") Then
					Return name.Left(name.Length - 3)
				End If
			End If
			
			If f.Extension <> "" And name.Length > (f.Extension.Length + 1) Then
				Return name.Left(name.Length - (f.Extension.Length + 1))
			End If
			
			Return name
		End Function
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Function SanitizeSymbolPart(s As String) As String
			Var out As String
			For i As Integer = 1 To s.Length
				Var ch As String = s.Middle(i - 1, 1)
				Var code As Integer = Asc(ch)
				
				Var isAZ As Boolean = (code >= 65 And code <= 90) Or (code >= 97 And code <= 122)
				Var is09 As Boolean = (code >= 48 And code <= 57)
				Var isAllowed As Boolean = isAZ Or is09 Or ch = "_" Or ch = "." Or ch = "$" Or ch = ":"
				If isAllowed Then
					out = out + ch
				Else
					out = out + "_"
				End If
			Next
			If out = "" Then Return "VM"
			Return out
		End Function
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Function CompareFolderItemByName(a As FolderItem, b As FolderItem) As Integer
			If a Is Nil And b Is Nil Then Return 0
			If a Is Nil Then Return -1
			If b Is Nil Then Return 1
			
			Var an As String = a.Name.Lowercase
			Var bn As String = b.Name.Lowercase
			If an < bn Then Return -1
			If an > bn Then Return 1
			Return 0
		End Function
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub EmitPushD()
			mOut.WriteLine("@SP")
			mOut.WriteLine("A=M")
			mOut.WriteLine("M=D")
			mOut.WriteLine("@SP")
			mOut.WriteLine("M=M+1")
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub EmitPopToD()
			mOut.WriteLine("@SP")
			mOut.WriteLine("AM=M-1")
			mOut.WriteLine("D=M")
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Function SegmentBaseSymbol(segment As String) As String
			Select Case segment.Lowercase
			Case "local"
				Return "LCL"
			Case "argument"
				Return "ARG"
			Case "this"
				Return "THIS"
			Case "that"
				Return "THAT"
			Else
				Return ""
			End Select
		End Function
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub HandleAdd()
			mOut.WriteLine("// add")
			mOut.WriteLine("@SP")
			mOut.WriteLine("AM=M-1")
			mOut.WriteLine("D=M")
			mOut.WriteLine("A=A-1")
			mOut.WriteLine("M=M+D")
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub HandleSub()
			mOut.WriteLine("// sub")
			mOut.WriteLine("@SP")
			mOut.WriteLine("AM=M-1")
			mOut.WriteLine("D=M")
			mOut.WriteLine("A=A-1")
			mOut.WriteLine("M=M-D")
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub HandleNeg()
			mOut.WriteLine("// neg")
			mOut.WriteLine("@SP")
			mOut.WriteLine("A=M-1")
			mOut.WriteLine("M=-M")
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub HandleAnd()
			mOut.WriteLine("// and")
			mOut.WriteLine("@SP")
			mOut.WriteLine("AM=M-1")
			mOut.WriteLine("D=M")
			mOut.WriteLine("A=A-1")
			mOut.WriteLine("M=M&D")
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub HandleOr()
			mOut.WriteLine("// or")
			mOut.WriteLine("@SP")
			mOut.WriteLine("AM=M-1")
			mOut.WriteLine("D=M")
			mOut.WriteLine("A=A-1")
			mOut.WriteLine("M=M|D")
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub HandleNot()
			mOut.WriteLine("// not")
			mOut.WriteLine("@SP")
			mOut.WriteLine("A=M-1")
			mOut.WriteLine("M=!M")
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub EmitComparison(jumpMnemonic As String)
			Var id As String = mCurrentVmBaseName + "_" + mLogicCounter.ToString
			mLogicCounter = mLogicCounter + 1
			
			Var trueLabel As String = "VM_TRUE_" + id
			Var endLabel As String = "VM_END_" + id
			
			mOut.WriteLine("@SP")
			mOut.WriteLine("AM=M-1")
			mOut.WriteLine("D=M")
			mOut.WriteLine("A=A-1")
			mOut.WriteLine("D=M-D")
			
			mOut.WriteLine("@" + trueLabel)
			mOut.WriteLine("D;" + jumpMnemonic)
			
			mOut.WriteLine("@SP")
			mOut.WriteLine("A=M-1")
			mOut.WriteLine("M=0")
			mOut.WriteLine("@" + endLabel)
			mOut.WriteLine("0;JMP")
			
			mOut.WriteLine("(" + trueLabel + ")")
			mOut.WriteLine("@SP")
			mOut.WriteLine("A=M-1")
			mOut.WriteLine("M=-1")
			
			mOut.WriteLine("(" + endLabel + ")")
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub HandleEq()
			mOut.WriteLine("// eq")
			EmitComparison("JEQ")
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub HandleGt()
			mOut.WriteLine("// gt")
			EmitComparison("JGT")
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub HandleLt()
			mOut.WriteLine("// lt")
			EmitComparison("JLT")
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub HandlePush(segment As String, index As Integer)
			Var seg As String = segment.Lowercase
			mOut.WriteLine("// push " + seg + " " + index.ToString)
			
			Select Case seg
			Case "constant"
				mOut.WriteLine("@" + index.ToString)
				mOut.WriteLine("D=A")
				EmitPushD
				Return
			
			Case "temp"
				Var addr As Integer = 5 + index
				mOut.WriteLine("@" + addr.ToString)
				mOut.WriteLine("D=M")
				EmitPushD
				Return
			
			Case "pointer"
				If index = 0 Then
					mOut.WriteLine("@THIS")
				Else
					mOut.WriteLine("@THAT")
				End If
				mOut.WriteLine("D=M")
				EmitPushD
				Return
			
			Case "static"
				Var sym As String = mCurrentVmBaseName + "." + index.ToString
				mOut.WriteLine("@" + sym)
				mOut.WriteLine("D=M")
				EmitPushD
				Return
			
			Else
				Var base As String = SegmentBaseSymbol(seg)
				If base <> "" Then
					mOut.WriteLine("@" + base)
					mOut.WriteLine("D=M")
					mOut.WriteLine("@" + index.ToString)
					mOut.WriteLine("A=D+A")
					mOut.WriteLine("D=M")
					EmitPushD
					Return
				End If
			End Select
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub HandlePop(segment As String, index As Integer)
			Var seg As String = segment.Lowercase
			mOut.WriteLine("// pop " + seg + " " + index.ToString)
			
			Select Case seg
			Case "temp"
				Var addr As Integer = 5 + index
				EmitPopToD
				mOut.WriteLine("@" + addr.ToString)
				mOut.WriteLine("M=D")
				Return
			
			Case "pointer"
				EmitPopToD
				If index = 0 Then
					mOut.WriteLine("@THIS")
				Else
					mOut.WriteLine("@THAT")
				End If
				mOut.WriteLine("M=D")
				Return
			
			Case "static"
				Var sym As String = mCurrentVmBaseName + "." + index.ToString
				EmitPopToD
				mOut.WriteLine("@" + sym)
				mOut.WriteLine("M=D")
				Return
			
			Else
				Var base As String = SegmentBaseSymbol(seg)
				If base <> "" Then
					mOut.WriteLine("@" + base)
					mOut.WriteLine("D=M")
					mOut.WriteLine("@" + index.ToString)
					mOut.WriteLine("D=D+A")
					mOut.WriteLine("@R13")
					mOut.WriteLine("M=D")
					
					EmitPopToD
					mOut.WriteLine("@R13")
					mOut.WriteLine("A=M")
					mOut.WriteLine("M=D")
					Return
				End If
			End Select
		End Sub
	#tag EndMethod
	
End Module
#tag EndModule
