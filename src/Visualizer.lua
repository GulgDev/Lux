local Visualizer = {
	colors = {
		primary   = Color3.fromRGB(46, 46, 46),
		secondary = Color3.fromRGB(37, 37, 37),
		hover     = Color3.fromRGB(74, 74, 74),
		selection = Color3.fromRGB(11, 90, 175),
		text      = Color3.fromRGB(204, 204, 204),
		border    = Color3.fromRGB(24, 24, 24)
	},
	
	assets = {
		arrowRight                  = "rbxassetid://12268318290",
		arrowDown                   = "rbxassetid://12268318664",
		tokenIcon                   = "rbxassetid://12267162801",
		structureIcon               = "rbxassetid://12267163178",
		treeIcon                    = "rbxassetid://12267675472",
		errorIcon                   = "rbxassetid://12288162376",
		errorGotIcon                = "rbxassetid://12288161740",
		errorExpectedIcon           = "rbxassetid://12288162023",
		eofIcon                     = "rbxassetid://12298324904",
		inlineWhitespaceIcon        = "rbxassetid://12298324618",
		multilineWhitespaceIcon     = "rbxassetid://12298324137",
		grammarIcon                 = "rbxassetid://12302354133",
		andChainRuleIcon            = "rbxassetid://12302354746",
		orChainRuleIcon             = "rbxassetid://12302352339",
		patternRuleIcon             = "rbxassetid://12302351956",
		includeRuleIcon             = "rbxassetid://12302353820",
		customRuleIcon              = "rbxassetid://12302354421",
		optionalRuleIcon            = "rbxassetid://12302352665",
		repeationRuleIcon           = "rbxassetid://12302351597",
		eofRuleIcon                 = "rbxassetid://12314811944"
	}
}

local Grammar = require(script.Parent.Grammar)
local Parser = require(script.Parent.Parser)
local AST = require(script.Parent.AST)

local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")

local loaded = false

local function load()
	loaded = true
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	local preload = {}
	for _, asset in Visualizer.assets do
		table.insert(preload, asset)
	end
	ContentProvider:PreloadAsync(preload)
end

local function assertEnabled()
	if not loaded then
		load()
	end
	assert(RunService:IsStudio() and
		RunService:IsRunning() and
		RunService:IsClient(),
		"Lux visualizer is diabled")
end

local screen
local function requestScreen(): ScreenGui
	assertEnabled()
	if not screen then
		local player = Players.LocalPlayer
		local playerGui = player.PlayerGui
		screen = playerGui:FindFirstChild("LuxVisualizer")
		if not screen then
			screen = Instance.new("ScreenGui", playerGui)
			screen.Name = "LuxVisualizer"
			screen.IgnoreGuiInset = true
		end
	end
	return screen
end

function Visualizer.gridLayout(frame: Frame, sizeX: number, sizeY: number, paddingX: number, paddingY: number)
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(sizeX, sizeY)
	layout.CellPadding = UDim2.fromOffset(paddingX, paddingY)
	layout.Parent = frame
end

function Visualizer.listLayout(frame: Frame, direction: Enum.FillDirection, horizaontalAlignment: Enum.HorizontalAlignment, verticalAlignment: Enum.VerticalAlignment, padding: number)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.HorizontalAlignment = horizaontalAlignment
	layout.VerticalAlignment = verticalAlignment
	layout.Padding = UDim.new(0, padding)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
end

function Visualizer.padding(frame: Frame, x: number, y: number)
	local padding = Instance.new("UIPadding")
	local paddingX = UDim.new(0, x)
	local paddingY = UDim.new(0, y)
	padding.PaddingLeft = paddingX
	padding.PaddingRight = paddingX
	padding.PaddingTop = paddingY
	padding.PaddingBottom = paddingY
	padding.Parent = frame
end

local canvas, explorer

function Visualizer.createCanvas(): Frame
	if canvas then
		canvas:Destroy()
	end
	if explorer then
		explorer = nil
	end
	canvas = Instance.new("Frame")
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundColor3 = Visualizer.colors.primary
	canvas.BorderSizePixel = 0
	canvas.Parent = requestScreen()
	return canvas
end

function Visualizer.createObjectExplorer(container: Frame)
	local canvas = Visualizer.createCanvas()
	local scrollingFrame = Instance.new("ScrollingFrame")
	Visualizer.padding(scrollingFrame, 16, 52)
	scrollingFrame.Size = UDim2.new(1, 0, 1, -160)
	scrollingFrame.BackgroundTransparency = 1
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollingFrame.CanvasSize = UDim2.fromScale(1, 0)
	scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, -44, 0, 0)
	content.BackgroundTransparency = 1
	content.AutomaticSize = Enum.AutomaticSize.Y
	local info = Instance.new("TextLabel")
	info.AnchorPoint = Vector2.new(0, 1)
	info.Position = UDim2.fromScale(0, 1)
	info.Size = UDim2.new(1, 0, 0, 160)
	info.BackgroundColor3 = Visualizer.colors.secondary
	info.BorderColor3 = Visualizer.colors.border
	info.TextColor3 = Visualizer.colors.text
	info.TextSize = 16
	info.TextWrapped = true
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.TextYAlignment = Enum.TextYAlignment.Top
	info.Text = ""
	Visualizer.padding(info, 10, 10)
	info.Parent = canvas
	content.Parent = scrollingFrame
	scrollingFrame.Parent = canvas
	explorer = {
		content = content,
		info = info
	}
end

function Visualizer.showObjectInformation(text: string)
	assert(explorer, "Can't access object explorer")
	explorer.info.Text = text
end

function Visualizer.hideObjectInformation()
	Visualizer.showObjectInformation("")
end

local selection

function Visualizer.createObjectHead(container: Frame, indent: number, icon: string, label: string, info: string, forSpoiler: boolean)
	local head = Instance.new("TextButton")
	head.Size = UDim2.new(1, 0, 0, 24)
	head.BackgroundColor3 = Visualizer.colors.primary
	head.BorderSizePixel = 0
	head.AutoButtonColor = false
	head.Text = ""
	Visualizer.listLayout(head,
		Enum.FillDirection.Horizontal,
		Enum.HorizontalAlignment.Left,
		Enum.VerticalAlignment.Center,
		8
	)
	Visualizer.padding(head, indent + if forSpoiler then 8 else 32, 0)
	local imageLabel = Instance.new("ImageLabel", head)
	imageLabel.Size = UDim2.fromOffset(16, 16)
	imageLabel.BackgroundTransparency = 1
	imageLabel.Image = icon
	imageLabel.LayoutOrder = 1
	imageLabel.Parent = head
	local textLabel = Instance.new("TextLabel")
	textLabel.AutomaticSize = Enum.AutomaticSize.XY
	textLabel.BackgroundTransparency = 1
	textLabel.TextSize = 16
	textLabel.TextColor3 = Visualizer.colors.text
	textLabel.Text = label
	textLabel.LayoutOrder = 2
	textLabel.Parent = head
	head.MouseEnter:Connect(function()
		if head.BackgroundColor3 == Visualizer.colors.primary then
			head.BackgroundColor3 = Visualizer.colors.hover
		end
	end)
	head.MouseLeave:Connect(function()
		if head.BackgroundColor3 == Visualizer.colors.hover then
			head.BackgroundColor3 = Visualizer.colors.primary
		end
	end)
	head.MouseButton1Click:Connect(function()
		if selection then
			selection.BackgroundColor3 = Visualizer.colors.primary
		end
		selection = head
		selection.BackgroundColor3 = Visualizer.colors.selection
		Visualizer.showObjectInformation(info)
	end)
	head.Parent = container
	return head
end

function Visualizer.createSpoiler(container: Frame, indent: number, expanded: boolean, icon: string, label: string, info: string)
	local head = Visualizer.createObjectHead(container, indent, icon, label, info, true)
	local arrow = Instance.new("ImageButton")
	arrow.Size = UDim2.fromOffset(16, 16)
	arrow.BackgroundTransparency = 1
	arrow.AutoButtonColor = false
	arrow.Image = if expanded then Visualizer.assets.arrowDown else Visualizer.assets.arrowRight
	arrow.LayoutOrder = 0
	arrow.Parent = head
	local childrenContainer = Instance.new("Frame")
	childrenContainer.Position = UDim2.fromOffset(0, 24)
	childrenContainer.Size = UDim2.fromScale(1, 0)
	childrenContainer.AutomaticSize = Enum.AutomaticSize.Y
	childrenContainer.BackgroundTransparency = 1
	if expanded then
		childrenContainer.Parent = container
	end
	local function toggle()
		if childrenContainer.Parent then
			childrenContainer.Parent = nil
			arrow.Image = Visualizer.assets.arrowRight
		else
			childrenContainer.Parent = container
			arrow.Image = Visualizer.assets.arrowDown
		end
	end
	arrow.MouseButton1Click:Connect(toggle)
	local latestClickTime = 0
	head.MouseButton1Click:Connect(function()
		local now = tick()
		if now - latestClickTime < .5 then 
			toggle()
			latestClickTime = 0
		else
			latestClickTime = now
		end
	end)
	return childrenContainer
end

function Visualizer.createObject(container: Frame, indent: number, icon: string, label: string, info: string)
	Visualizer.createObjectHead(container, indent, icon, label, info, false)
end

function Visualizer.renderSpoilerElement(container: Frame, indent: number, expanded: boolean, icon: string, label: string, info: string, children: { AST.Element })
	local childrenContainer = Visualizer.createSpoiler(container, indent, expanded, icon, label, info)
	Visualizer.renderElements(childrenContainer, indent + 24, children)
end

function Visualizer.renderElements(container: Frame, indent: number, elements: { AST.Element })
	Visualizer.listLayout(container,
		Enum.FillDirection.Vertical,
		Enum.HorizontalAlignment.Left,
		Enum.VerticalAlignment.Top,
		0
	)
	for index, element in elements do
		local elementContainer = Instance.new("Frame")
		elementContainer.Size = UDim2.fromScale(1, 0)
		elementContainer.AutomaticSize = Enum.AutomaticSize.Y
		elementContainer.BackgroundTransparency = 1
		elementContainer.LayoutOrder = index
		if element.elementType == "token" then
			Visualizer.createObject(elementContainer,
				indent,
				Visualizer.assets.tokenIcon,
				element.value:gsub("\n", " "):gsub("\t", "    "),
				`Token\n  Value: {Parser.escape(element.value)}\n  Start: {element.start.offset} (line {element.start.line}, column {element.start.column})\n  Stop: {element.stop.offset} (line {element.stop.line}, column {element.stop.column})\n  Length: {#element.value}`
			)
		elseif element.elementType == "structure" then
			Visualizer.renderSpoilerElement(elementContainer,
				indent,
				false,
				Visualizer.assets.structureIcon,
				element.name,
				`Structure\n  Name: "{element.name}"\n  Children: {#element.children}\n  Descendants: {#element:getDescendants()}`,
				element.children
			)
		elseif element.elementType == "whitespace" then
			Visualizer.createObject(elementContainer,
				indent,
				if element.multiline then
					Visualizer.assets.multilineWhitespaceIcon
					else 
					Visualizer.assets.inlineWhitespaceIcon,
				"Whitespace",
				`Whitespace\n  Multiline: {if element.multiline then "yes" else "no"}`
			)
		elseif element.elementType == "eof" then
			Visualizer.createObject(elementContainer,
				indent,
				Visualizer.assets.eofIcon,
				"EOF",
				`End of file\n  Position: {element.position.offset} (line {element.position.line}, column {element.position.column})`
			)
		elseif element.elementType == "error" then
			local info = "Error"
			local errorChildrenContainer = Visualizer.createSpoiler(elementContainer,
				indent,
				false,
				Visualizer.assets.errorIcon,
				"Error",
				info
			)
			Visualizer.listLayout(errorChildrenContainer,
				Enum.FillDirection.Vertical,
				Enum.HorizontalAlignment.Left,
				Enum.VerticalAlignment.Top,
				0
			)
			local gotContainer = Instance.new("Frame")
			gotContainer.Size = UDim2.fromScale(1, 0)
			gotContainer.AutomaticSize = Enum.AutomaticSize.Y
			gotContainer.BackgroundTransparency = 1
			gotContainer.LayoutOrder = 0
			local gotChildrenContainer = Visualizer.createSpoiler(gotContainer,
				indent + 24,
				false,
				Visualizer.assets.errorGotIcon,
				"Got",
				info
			)
			Visualizer.renderElements(gotChildrenContainer,
				indent + 48,
				{ element.got }
			)
			gotContainer.Parent = errorChildrenContainer
			local expectedContainer = Instance.new("Frame")
			expectedContainer.Size = UDim2.fromScale(1, 0)
			expectedContainer.AutomaticSize = Enum.AutomaticSize.Y
			expectedContainer.BackgroundTransparency = 1
			expectedContainer.LayoutOrder = 1
			local expectedChildrenContainer = Visualizer.createSpoiler(expectedContainer,
				indent + 24,
				false,
				Visualizer.assets.errorExpectedIcon,
				"Expected",
				info
			)
			Visualizer.renderGrammaticalRules(expectedChildrenContainer,
				indent + 48,
				{ element.expected }
			)
			expectedContainer.Parent = errorChildrenContainer
		end
		elementContainer.Parent = container
	end
end

function Visualizer.renderGrammaticalRule(container: Frame, indent: number, rule: Grammar.GrammaticalRule, name: string?)
	if rule.class == "pattern" then
		Visualizer.createObject(container,
			indent,
			Visualizer.assets.patternRuleIcon,
			name or "Pattern",
			`Pattern: {Parser.escape(rule.pattern)}`
		)
	elseif rule.class == "include" then
		Visualizer.createObject(container,
			indent,
			Visualizer.assets.includeRuleIcon,
			name or "Include",
			`Include\n  Rule: {rule.ruleName}`
		)
	elseif rule.class == "custom" then
		Visualizer.createObject(container,
			indent,
			Visualizer.assets.customRuleIcon,
			name or "Custom",
			"Custom rule"
		)
	elseif rule.class == "eof" then
		Visualizer.createObject(container,
			indent,
			Visualizer.assets.eofRuleIcon,
			"EOF",
			"End of file"
		)
	elseif rule.class == "chain" then
		local childrenFrame = Visualizer.createSpoiler(container,
			indent,
			false,
			if rule.operation == "and" then Visualizer.assets.andChainRuleIcon else Visualizer.assets.orChainRuleIcon,
			name or if rule.operation == "and" then "And-chain" else "Or-chain",
			`Chain\n  Operation: {rule.operation}`
		)
		Visualizer.renderGrammaticalRules(childrenFrame, indent + 24, rule.rules)
	elseif rule.class == "modifier" then
		local childrenFrame = Visualizer.createSpoiler(container,
			indent,
			false,
			if rule.modifier == "optional" then Visualizer.assets.optionalRuleIcon else Visualizer.assets.repeationRuleIcon,
			name or if rule.modifier == "optional" then "Optional" else "Repeation",
			`Rule modifier: {rule.modifier}`
		)
		Visualizer.renderGrammaticalRule(childrenFrame, indent + 24, rule.rule)
	end
end

function Visualizer.renderGrammaticalRules(container: Frame, indent: number, rules: { Grammar.GrammaticalRule })
	Visualizer.listLayout(container,
		Enum.FillDirection.Vertical,
		Enum.HorizontalAlignment.Left,
		Enum.VerticalAlignment.Top,
		0
	)
	local index = 1
	for key, rule in rules do
		local ruleContainer = Instance.new("Frame")
		ruleContainer.Size = UDim2.fromScale(1, 0)
		ruleContainer.AutomaticSize = Enum.AutomaticSize.Y
		ruleContainer.BackgroundTransparency = 1
		ruleContainer.LayoutOrder = index
		ruleContainer.Parent = container
		Visualizer.renderGrammaticalRule(ruleContainer,
			indent,
			rule,
			if key == index then nil else key
		)
		index += 1
	end
end

function Visualizer.renderSyntaxTree(container: Frame, tree: AST.SyntaxTree)
	local root = tree.root
	local rootElementContainer = Instance.new("Frame")
	rootElementContainer.Size = UDim2.fromScale(1, 0)
	rootElementContainer.AutomaticSize = Enum.AutomaticSize.Y
	rootElementContainer.BackgroundColor3 = Visualizer.colors.primary
	rootElementContainer.BorderSizePixel = 0
	rootElementContainer.Parent = container
	Visualizer.renderSpoilerElement(rootElementContainer,
		0,
		true,
		Visualizer.assets.treeIcon,
		root.name,
		`Syntax tree\n  Root: "{root.name}"\n  Children: {#root.children}\n  Descendants: {#root:getDescendants()}`,
		root.children
	)
end

function Visualizer.renderGrammar(container: Frame, grammar: Grammar.Grammar)
	local grammarContainer = Instance.new("Frame")
	grammarContainer.Size = UDim2.fromScale(1, 0)
	grammarContainer.AutomaticSize = Enum.AutomaticSize.Y
	grammarContainer.BackgroundColor3 = Visualizer.colors.primary
	grammarContainer.BorderSizePixel = 0
	grammarContainer.Parent = container
	local childrenContainer = Visualizer.createSpoiler(grammarContainer,
		0,
		true,
		Visualizer.assets.grammarIcon,
		"Grammar",
		`Grammar\n  Root rule: "{grammar.rootRule}"`
	)
	Visualizer.renderGrammaticalRules(childrenContainer, 24, grammar.rules)
end

function Visualizer.showSyntaxTree(tree: AST.SyntaxTree)
	Visualizer.createObjectExplorer()
	Visualizer.renderSyntaxTree(explorer.content, tree)
end

function Visualizer.showGrammar(grammar: Grammar.Grammar)
	Visualizer.createObjectExplorer()
	Visualizer.renderGrammar(explorer.content, grammar)
end

function Visualizer.showElements(elements: { AST.Element })
	Visualizer.createObjectExplorer()
	Visualizer.renderElements(explorer.content, 0, elements)
end

return Visualizer
