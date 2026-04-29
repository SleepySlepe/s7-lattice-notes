using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace MobListEditor
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }
    }

    internal sealed class TacticEntry { public string Section; public bool IsSection; public int MobID; public string MonsterName; public string Behavior; public string Priority; public string Skill; public int SkillLevel; }
    internal sealed class HomunculusSkillDefinition { public string Family; public string SkillKey; public string DisplayName; public int DefaultMinSPPercent; public int DefaultLevel; public HomunculusSkillDefinition(string family, string skillKey, string displayName, int defaultMinSpPercent, int defaultLevel) { Family = family; SkillKey = skillKey; DisplayName = displayName; DefaultMinSPPercent = defaultMinSpPercent; DefaultLevel = defaultLevel; } }
    internal sealed class HomunculusSkillState { public int MinSPPercent; public int Level; public int OwnerHPPercent; public int HomunHPPercent; }
    internal sealed class SkillEditorRow { public NumericUpDown MinSPPercent; public ComboBox Level; }
    internal sealed class PatrolSettings { public bool Enabled; public string Shape; public int Distance; }
    internal sealed class RuntimeSettings { public bool DefendOwner; public bool TurretStayOnCell; public bool? NoKS; public string KSMode; public bool AntiStuckEnabled; public int AntiStuckMs; public bool FollowOwnerOnMove; public int FollowOwnerDelayMs; public int SoftResetMs; public int OwnerResumeMs; public int PostSkillWaitMs; public bool DanceAttackEnabled; public bool DanceMovingOnly; public bool DanceEveryAttack; public int DanceMoveMs; }
    internal sealed class EditorProfileSnapshot { public string Id; public string Name; public string BehaviorMode; public string TacticsMode; public List<TacticEntry> Whitelist; public List<TacticEntry> Blacklist; public Dictionary<string, HomunculusSkillState> HomunculusSkills; public PatrolSettings Patrol; public RuntimeSettings Runtime; }
    internal sealed class EditorProfileMeta { public string Id; public string Name; }
    internal sealed class EditorProfileStore { public string ActiveProfileId; public string AltTAction; public string AltTProfileId; public List<EditorProfileMeta> Profiles; }
    internal sealed class LegacyEditorProfileStore { public string ActiveProfileId; public string AltTAction; public string AltTProfileId; public List<EditorProfileSnapshot> Profiles; }
    internal sealed class ProfileListItem { public string Id; public string Name; public ProfileListItem(string id, string name) { Id = id; Name = name; } public override string ToString() { return Name; } }
    internal sealed class UpdateManifest { public string Version; public string Channel; public List<UpdateFile> Files; public List<string> Preserve; public List<string> Notes; }
    internal sealed class UpdateFile { public string Path; public string Kind; }
    internal sealed class BufferedTabControl : TabControl
    {
        public BufferedTabControl()
        {
            SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint, true);
            UpdateStyles();
        }
    }
    internal sealed class BufferedDataGridView : DataGridView
    {
        public BufferedDataGridView()
        {
            DoubleBuffered = true;
            SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint, true);
            UpdateStyles();
        }
    }

    internal sealed class MainForm : Form
    {
        private static readonly string[] BehaviorOptions = { "Slepe Mode", "Snipe", "Avoid", "React", "Attack" };
        private static readonly string[] TacticBehaviorOptions = { "", "Slepe Mode", "Snipe", "Avoid", "Kite Attack", "Kite No Attack", "Attack", "React" };
        private static readonly string[] TacticPriorityOptions = { "", "First", "Normal", "Last" };
        private static readonly string[] KsModeOptions = { "No KS", "First Attack", "Full KS" };
        private static readonly string[] SkillLevelOptions = { "", "1", "2", "3", "4", "5" };
        private static readonly string[] HomunculusSkillLevelOptions = { "OFF", "Lv1", "Lv2", "Lv3", "Lv4", "Lv5" };
        private static readonly string[] HomunculusFamilies = { "Amistr", "Filir", "Lif", "Vanilmirth" };
        private const int MaxTacticSkillCount = 999;
        private static readonly string[] UpdateManifestUrls =
        {
            "https://raw.githubusercontent.com/SleepySlepe/s7-lattice-notes/main/update-manifest.json",
            "https://raw.githubusercontent.com/SleepySlepe/s7-lattice-notes/master/update-manifest.json",
            "https://github.com/SleepySlepe/s7-lattice-notes/raw/refs/heads/main/update-manifest.json",
            "https://github.com/SleepySlepe/s7-lattice-notes/raw/refs/heads/master/update-manifest.json"
        };
        private static readonly string[] AllowedUpdateFiles =
        {
            "AI.lua",
            "AI_M.lua",
            "Const.lua",
            "Util.lua",
            "SlepeAI Settings.exe",
            "SlepeAI Settings.cs"
        };
        private static readonly string[] ProtectedUpdateFiles =
        {
            "TargetLists.lua",
            "SlepeAI Settings Profiles.json",
            "Profiles"
        };
        private static readonly HomunculusSkillDefinition[] HomunculusSkillDefinitions =
        {
            new HomunculusSkillDefinition("Amistr", "Bulwark", "Bulwark", 40, 0),
            new HomunculusSkillDefinition("Amistr", "Casting", "Casting", 10, 0),
            new HomunculusSkillDefinition("Filir", "Moonlight", "Moonlight", 38, 2),
            new HomunculusSkillDefinition("Filir", "AcceleratedFlight", "Over Speed", 30, 1),
            new HomunculusSkillDefinition("Filir", "Flitting", "Fleet Move", 35, 0),
            new HomunculusSkillDefinition("Lif", "HealingTouch", "Healing Touch", 30, 5),
            new HomunculusSkillDefinition("Lif", "UrgentEscape", "Urgent Escape", 40, 0),
            new HomunculusSkillDefinition("Vanilmirth", "Caprice", "Caprice", 5, 5),
            new HomunculusSkillDefinition("Vanilmirth", "ChaoticBlessings", "C.Blessing", 40, 0),
        };

        private readonly string _targetListsPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "TargetLists.lua");
        private readonly string _profilesPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "SlepeAI Settings Profiles.json");
        private readonly string _profilesDirectory = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Profiles");
        private readonly Dictionary<string, SkillEditorRow> _homunculusSkillRows = new Dictionary<string, SkillEditorRow>(StringComparer.OrdinalIgnoreCase);
        private readonly JavaScriptSerializer _serializer = new JavaScriptSerializer();
        private readonly ToolTip _toolTip = new ToolTip();
        private EditorProfileStore _profileStore;
        private ComboBox _behaviorComboBox;
        private Label _behaviorDescriptionLabel;
        private CheckBox _patrolEnabledCheckBox;
        private ComboBox _patrolShapeComboBox;
        private NumericUpDown _patrolDistanceNumeric;
        private ComboBox _profileComboBox;
        private ComboBox _altTActionComboBox;
        private ComboBox _altTProfileComboBox;
        private CheckBox _defendOwnerCheckBox;
        private CheckBox _turretStayOnCellCheckBox;
        private ComboBox _ksModeComboBox;
        private CheckBox _antiStuckEnabledCheckBox;
        private NumericUpDown _antiStuckMsNumeric;
        private CheckBox _followOwnerOnMoveCheckBox;
        private NumericUpDown _followOwnerDelayMsNumeric;
        private NumericUpDown _softResetMsNumeric;
        private NumericUpDown _ownerResumeMsNumeric;
        private NumericUpDown _postSkillWaitMsNumeric;
        private CheckBox _danceAttackEnabledCheckBox;
        private CheckBox _danceMovingOnlyCheckBox;
        private CheckBox _danceEveryAttackCheckBox;
        private NumericUpDown _danceMoveMsNumeric;
        private NumericUpDown _chaoticBlessingsOwnerHpNumeric;
        private NumericUpDown _chaoticBlessingsHomunHpNumeric;
        private ComboBox _modeComboBox;
        private Label _activeListLabel;
        private Label _statusLabel;
        private Panel _startupOverlayPanel;
        private Label _startupOverlayLabel;
        private Timer _statusClearTimer;
        private Label _offLabel;
        private DataGridView _whitelistGrid;
        private DataGridView _blacklistGrid;
        private bool _suppressProfileSelectionChanged;
        private bool _isDirty;
        private bool _loadingUi;
        private bool _startupLoaded;

        public MainForm()
        {
            _loadingUi = true;
            SuspendLayout();
            Text = "SlepeAI Settings";
            Width = 1240;
            Height = 820;
            MinimumSize = new Size(1120, 720);
            StartPosition = FormStartPosition.CenterScreen;
            SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint, true);
            UpdateStyles();
            _toolTip.AutomaticDelay = 200;
            _toolTip.InitialDelay = 200;
            _toolTip.ReshowDelay = 100;
            _toolTip.AutoPopDelay = 12000;
            _toolTip.ShowAlways = true;
            _toolTip.IsBalloon = true;

            var root = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2, Padding = new Padding(12) };
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 100f));
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            Controls.Add(root);

            var tabs = new BufferedTabControl { Dock = DockStyle.Fill };
            root.Controls.Add(tabs, 0, 0);
            var behaviorTab = new TabPage("Behavior");
            var tacticsTab = new TabPage("Tactics");
            var homunculusSkillsTab = new TabPage("Homunculus Skills");
            tabs.TabPages.Add(behaviorTab);
            tabs.TabPages.Add(tacticsTab);
            tabs.TabPages.Add(homunculusSkillsTab);
            BuildBehaviorTab(behaviorTab);
            BuildTacticsTab(tacticsTab);
            BuildHomunculusSkillsTab(homunculusSkillsTab);
            HookDirtyTracking(this);

            var footer = new TableLayoutPanel { Dock = DockStyle.Top, ColumnCount = 3, AutoSize = true };
            footer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f));
            footer.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            footer.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            root.Controls.Add(footer, 0, 1);
            _statusLabel = new Label { AutoSize = true, Text = "Ready", Anchor = AnchorStyles.Left, Margin = new Padding(0, 10, 0, 0), ForeColor = Color.FromArgb(70, 70, 70), Font = new Font("Segoe UI", 11f, FontStyle.Bold) };
            footer.Controls.Add(_statusLabel, 0, 0);
            _statusClearTimer = new Timer { Interval = 5000 };
            _statusClearTimer.Tick += delegate { _statusClearTimer.Stop(); SetStatusMessage("Ready", Color.FromArgb(70, 70, 70), false); };
            var updateButton = new Button { Text = "Check Updates", AutoSize = true, Margin = new Padding(8, 6, 0, 0) };
            updateButton.Click += delegate { CheckForUpdates(); };
            footer.Controls.Add(updateButton, 1, 0);
            var saveButton = new Button { Text = "Save Lua", AutoSize = true, Margin = new Padding(8, 6, 0, 0) };
            saveButton.Click += delegate { SaveFile(); };
            footer.Controls.Add(saveButton, 2, 0);

            _startupOverlayPanel = BuildStartupOverlay();
            Controls.Add(_startupOverlayPanel);
            _startupOverlayPanel.BringToFront();

            UpdateBehaviorDescription();
            UpdateTacticsModeView();
            ApplyHomunculusSkillSettings(GetDefaultHomunculusSkillStates());
            EnableSmoothPainting(this);
            ResumeLayout(false);
            Shown += MainForm_Shown;
            FormClosing += MainForm_FormClosing;
        }

        private Panel BuildStartupOverlay()
        {
            var overlay = new Panel { Dock = DockStyle.Fill, BackColor = Color.FromArgb(245, 247, 250) };
            var card = new TableLayoutPanel { AutoSize = true, ColumnCount = 1, RowCount = 3, BackColor = Color.White, Padding = new Padding(18) };
            card.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            card.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            card.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            var title = new Label { AutoSize = true, Text = "SlepeAI Settings", Font = new Font("Segoe UI", 14f, FontStyle.Bold), ForeColor = Color.FromArgb(35, 35, 35), Margin = new Padding(0, 0, 0, 6) };
            _startupOverlayLabel = new Label { AutoSize = true, Text = "Loading settings...", Font = new Font("Segoe UI", 10f, FontStyle.Regular), ForeColor = Color.FromArgb(80, 80, 80), Margin = new Padding(0, 0, 0, 10) };
            var progress = new ProgressBar { Style = ProgressBarStyle.Marquee, MarqueeAnimationSpeed = 22, Width = 280, Height = 18 };
            card.Controls.Add(title, 0, 0);
            card.Controls.Add(_startupOverlayLabel, 0, 1);
            card.Controls.Add(progress, 0, 2);

            overlay.Controls.Add(card);
            overlay.Resize += delegate
            {
                card.Left = Math.Max(0, (overlay.ClientSize.Width - card.Width) / 2);
                card.Top = Math.Max(0, (overlay.ClientSize.Height - card.Height) / 2);
            };
            return overlay;
        }

        private void MainForm_Shown(object sender, EventArgs e)
        {
            if (_startupLoaded) return;
            _startupLoaded = true;
            BeginInvoke((MethodInvoker)LoadStartupData);
        }

        private void LoadStartupData()
        {
            try
            {
                SetStartupOverlayMessage("Loading settings...");
                _profileStore = ReadProfileStore();
                var hasProfiles = _profileStore != null && _profileStore.Profiles != null && _profileStore.Profiles.Count > 0;
                if (hasProfiles == false)
                {
                    SetStartupOverlayMessage("Loading target list...");
                    LoadFile();
                }

                SetStartupOverlayMessage("Loading profiles...");
                LoadProfiles(false);
                SetDirty(false);
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, ex.Message, "Load failed", MessageBoxButtons.OK, MessageBoxIcon.Error);
                SetStatusMessage("Load failed", Color.FromArgb(180, 45, 45), true);
            }
            finally
            {
                _loadingUi = false;
                if (_startupOverlayPanel != null)
                {
                    _startupOverlayPanel.Visible = false;
                    _startupOverlayPanel.SendToBack();
                }
            }
        }

        private void SetStartupOverlayMessage(string text)
        {
            if (_startupOverlayLabel != null)
            {
                _startupOverlayLabel.Text = text;
                _startupOverlayLabel.Refresh();
            }
            if (_startupOverlayPanel != null)
            {
                _startupOverlayPanel.Refresh();
            }
        }

        private void EnableSmoothPainting(Control root)
        {
            if (root == null) return;
            SetDoubleBuffered(root);
            foreach (Control child in root.Controls) EnableSmoothPainting(child);
        }

        private static void SetDoubleBuffered(Control control)
        {
            if (control == null) return;
            if (control is TextBox || control is ComboBox || control is NumericUpDown) return;
            var property = typeof(Control).GetProperty("DoubleBuffered", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
            if (property != null)
            {
                property.SetValue(control, true, null);
            }
        }

        private void SetStatusMessage(string text, Color color, bool autoClear)
        {
            _statusLabel.Text = text;
            _statusLabel.ForeColor = color;
            if (_statusClearTimer == null) return;
            _statusClearTimer.Stop();
            if (autoClear) _statusClearTimer.Start();
        }

        private void BuildBehaviorTab(TabPage tab)
        {
            var scrollPanel = new Panel { Dock = DockStyle.Fill, AutoScroll = true };
            tab.Controls.Add(scrollPanel);

            var layout = new TableLayoutPanel { Dock = DockStyle.Top, ColumnCount = 1, RowCount = 7, Padding = new Padding(12), AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink };
            layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            scrollPanel.Controls.Add(layout);
            layout.Controls.Add(BuildProfilesGroup(), 0, 0);
            var row = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true };
            row.Controls.Add(new Label { Text = "Overall Behavior", AutoSize = true, Margin = new Padding(0, 6, 8, 0) });
            _behaviorComboBox = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 220 };
            _behaviorComboBox.Items.AddRange(BehaviorOptions);
            _behaviorComboBox.SelectedIndex = 0;
            _behaviorComboBox.SelectedIndexChanged += delegate { UpdateBehaviorDescription(); };
            row.Controls.Add(_behaviorComboBox);
            layout.Controls.Add(row, 0, 1);
            layout.Controls.Add(new Label { Text = "This tab sets the global behavior mode. The checklist below shows extra live AI rules that already exist in Lua and apply alongside the editor settings.", AutoSize = true, ForeColor = Color.FromArgb(70, 70, 70), Margin = new Padding(0, 4, 0, 8) }, 0, 2);
            _behaviorDescriptionLabel = new Label
            {
                Dock = DockStyle.Top,
                AutoSize = false,
                Height = 76,
                BorderStyle = BorderStyle.FixedSingle,
                Padding = new Padding(10),
                Margin = new Padding(0, 0, 0, 8),
                BackColor = Color.FromArgb(248, 249, 252),
                TextAlign = ContentAlignment.TopLeft
            };
            layout.Controls.Add(_behaviorDescriptionLabel, 0, 3);
            layout.Controls.Add(BuildPatrolGroup(), 0, 4);
            layout.Controls.Add(BuildRuntimeGroup(), 0, 5);
            layout.Controls.Add(BuildBehaviorFeaturesGroup(), 0, 6);
        }

        private Control BuildPatrolGroup()
        {
            var group = new GroupBox { Text = "Patrol", Dock = DockStyle.Top, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, Padding = new Padding(10), Margin = new Padding(0, 4, 0, 0) };
            var layout = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true, WrapContents = true };
            group.Controls.Add(layout);
            _patrolEnabledCheckBox = new CheckBox { Text = "Enable Patrol", AutoSize = true, Margin = new Padding(0, 6, 16, 0) };
            layout.Controls.Add(_patrolEnabledCheckBox);
            layout.Controls.Add(CreateHelpLabel("When enabled, patrol runs only while no valid targets are available. It patrols around your standby point, or around the anchor spot if turret mode is active."));
            layout.Controls.Add(new Label { Text = "Pattern", AutoSize = true, Margin = new Padding(0, 8, 8, 0) });
            _patrolShapeComboBox = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 160 };
            _patrolShapeComboBox.Items.AddRange(new object[] { "Square CW", "Square CCW", "Diamond CW", "Diamond CCW", "Circle CW", "Circle CCW" });
            _patrolShapeComboBox.SelectedIndex = 0;
            layout.Controls.Add(_patrolShapeComboBox);
            layout.Controls.Add(new Label { Text = "Distance", AutoSize = true, Margin = new Padding(16, 8, 8, 0) });
            _patrolDistanceNumeric = new NumericUpDown { Minimum = 1, Maximum = 12, Value = 4, Width = 70 };
            layout.Controls.Add(_patrolDistanceNumeric);
            return group;
        }

        private Control BuildProfilesGroup()
        {
            var group = new GroupBox { Text = "Profiles", Dock = DockStyle.Top, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, Padding = new Padding(10), Margin = new Padding(0, 0, 0, 4) };
            var layout = new TableLayoutPanel { Dock = DockStyle.Top, AutoSize = true, ColumnCount = 1 };
            group.Controls.Add(layout);

            var profileRow = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true, WrapContents = true };
            profileRow.Controls.Add(new Label { Text = "Profile", AutoSize = true, Margin = new Padding(0, 8, 8, 0) });
            _profileComboBox = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 240 };
            _profileComboBox.SelectedIndexChanged += delegate { HandleProfileSelectionChanged(); };
            profileRow.Controls.Add(_profileComboBox);
            var applyButton = new Button { Text = "Apply", AutoSize = true, Margin = new Padding(8, 2, 0, 0) };
            applyButton.Click += delegate { ApplySelectedProfile(); };
            profileRow.Controls.Add(applyButton);
            var newButton = new Button { Text = "New", AutoSize = true, Margin = new Padding(8, 2, 0, 0) };
            newButton.Click += delegate { CreateProfile(); };
            profileRow.Controls.Add(newButton);
            var renameButton = new Button { Text = "Rename", AutoSize = true, Margin = new Padding(8, 2, 0, 0) };
            renameButton.Click += delegate { RenameProfile(); };
            profileRow.Controls.Add(renameButton);
            var deleteButton = new Button { Text = "Delete", AutoSize = true, Margin = new Padding(8, 2, 0, 0) };
            deleteButton.Click += delegate { DeleteProfile(); };
            profileRow.Controls.Add(deleteButton);
            layout.Controls.Add(profileRow, 0, 0);

            var altTRow = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true, WrapContents = true, Margin = new Padding(0, 8, 0, 0) };
            altTRow.Controls.Add(new Label { Text = "Standby Action", AutoSize = true, Margin = new Padding(0, 8, 8, 0) });
            _altTActionComboBox = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 180 };
            _altTActionComboBox.Items.AddRange(new object[] { "Standard Standby", "Quick Swap Profile", "Do Nothing", "Refresh" });
            _altTActionComboBox.SelectedIndex = 0;
            _altTActionComboBox.SelectedIndexChanged += delegate { UpdateAltTProfileState(); };
            altTRow.Controls.Add(_altTActionComboBox);
            altTRow.Controls.Add(new Label { Text = "Quick Swap Target", AutoSize = true, Margin = new Padding(16, 8, 8, 0) });
            _altTProfileComboBox = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 240 };
            altTRow.Controls.Add(_altTProfileComboBox);
            layout.Controls.Add(altTRow, 0, 1);

            layout.Controls.Add(new Label { Text = "Profile 1 starts as your current system and can be renamed. Profiles are editor-side for now; standby actions are not wired into Lua yet.", AutoSize = true, ForeColor = Color.FromArgb(70, 70, 70), Margin = new Padding(0, 8, 0, 0) }, 0, 2);
            return group;
        }

        private Control BuildRuntimeGroup()
        {
            var group = new GroupBox { Text = "Timing / Testing", Dock = DockStyle.Top, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, Padding = new Padding(10), Margin = new Padding(0, 4, 0, 0) };
            var layout = new TableLayoutPanel { Dock = DockStyle.Top, ColumnCount = 3, AutoSize = true };
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            group.Controls.Add(layout);

            AddToggleTimingRow(layout, 0, "Anti-Stuck Reset", true, out _antiStuckEnabledCheckBox, out _antiStuckMsNumeric, 100, 5000, 500, "If enabled, the homunculus can force a reassess after staying truly idle too long.");
            AddToggleTimingRow(layout, 1, "Abandon To Follow Owner", true, out _followOwnerOnMoveCheckBox, out _followOwnerDelayMsNumeric, 0, 5000, 0, "If enabled, the homunculus can drop what it is doing and follow you when you move. The number is the delay before that follow begins.");
            AddTimingRow(layout, 2, "Soft Reset Reassess (ms)", out _softResetMsNumeric, 100, 5000, 400, "How long the soft reset waits before it is allowed to look for a target again.");
            AddTimingRow(layout, 3, "Resume After Owner Stops (ms)", out _ownerResumeMsNumeric, 0, 2000, 100, "How long the homunculus keeps following you after you stop moving before it becomes aggressive again.");
            AddTimingRow(layout, 4, "Post-Skill Wait (ms)", out _postSkillWaitMsNumeric, 0, 10000, 700, "After casting on its current chase target, the homunculus stands still for this long before reassessing instead of falling straight into standby.");
            AddDanceAttackRow(layout, 5);

            return group;
        }

        private Control BuildBehaviorFeaturesGroup()
        {
            var group = new GroupBox { Text = "Live AI Features", Dock = DockStyle.Top, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, Padding = new Padding(10), Margin = new Padding(0, 4, 0, 0) };
            var layout = new TableLayoutPanel { Dock = DockStyle.Top, ColumnCount = 3, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink };
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            group.Controls.Add(layout);

            _defendOwnerCheckBox = AddInteractiveFeatureRow(layout, 0, "Defend Owner", true, "If enabled, owner defense bypasses whitelist and blacklist and takes priority when mobs are on you.");
            AddFeatureRow(layout, 1, "Turret Mode", "MOVE command anchors the homunculus to the clicked spot and makes it fight around that area instead of following normally.");
            _turretStayOnCellCheckBox = AddInteractiveFeatureRow(layout, 2, "Stay On Cell", false, "When turret mode is active, the homunculus stays on the anchored cell and only attacks or casts when the target is already in range.");
            _turretStayOnCellCheckBox.Margin = new Padding(24, 2, 6, 10);
            _ksModeComboBox = AddComboFeatureRow(layout, 3, "KS Mode", KsModeOptions, "No KS", "Choose how strictly the homunculus avoids kill stealing. No KS never touches other players' mobs, First Attack keeps going only if your homunculus landed the first auto-attack, and Full KS ignores KS protection entirely.");
            return group;
        }

        private void AddFeatureRow(TableLayoutPanel layout, int rowIndex, string title, string description)
        {
            layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            var box = new CheckBox { Checked = true, AutoCheck = false, AutoSize = true, Margin = new Padding(0, 2, 6, 10), Anchor = AnchorStyles.Top | AnchorStyles.Left, Text = title };
            var help = CreateHelpLabel(description);
            help.Margin = new Padding(0, 2, 0, 10);
            layout.Controls.Add(box, 0, rowIndex);
            layout.Controls.Add(help, 1, rowIndex);
        }

        private CheckBox AddInteractiveFeatureRow(TableLayoutPanel layout, int rowIndex, string title, bool isChecked, string description)
        {
            layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            var box = new CheckBox { Checked = isChecked, AutoSize = true, Margin = new Padding(0, 2, 6, 10), Anchor = AnchorStyles.Top | AnchorStyles.Left, Text = title };
            var help = CreateHelpLabel(description);
            help.Margin = new Padding(0, 2, 0, 10);
            layout.Controls.Add(box, 0, rowIndex);
            layout.Controls.Add(help, 1, rowIndex);
            return box;
        }

        private ComboBox AddComboFeatureRow(TableLayoutPanel layout, int rowIndex, string title, string[] options, string selectedOption, string description)
        {
            layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            var label = new Label { Text = title, AutoSize = true, Margin = new Padding(0, 8, 8, 0) };
            var comboBox = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 140, Margin = new Padding(0, 2, 6, 10) };
            comboBox.Items.AddRange(options);
            comboBox.SelectedItem = selectedOption;
            var help = CreateHelpLabel(description);
            help.Margin = new Padding(0, 2, 0, 10);
            layout.Controls.Add(label, 0, rowIndex);
            layout.Controls.Add(comboBox, 1, rowIndex);
            layout.Controls.Add(help, 2, rowIndex);
            return comboBox;
        }

        private Label CreateHelpLabel(string description)
        {
            var help = new Label
            {
                AutoSize = true,
                Text = "?",
                Cursor = Cursors.Help,
                ForeColor = Color.FromArgb(35, 90, 170),
                Font = new Font("Segoe UI", 9f, FontStyle.Bold),
                Margin = new Padding(0, 4, 8, 0)
            };
            _toolTip.SetToolTip(help, description);
            help.MouseHover += (sender, args) => _toolTip.Show(description, help, help.Width / 2, help.Height + 4, 12000);
            help.MouseLeave += (sender, args) => _toolTip.Hide(help);
            help.Click += (sender, args) => MessageBox.Show(this, description, "Help", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return help;
        }

        private void AddTimingRow(TableLayoutPanel layout, int rowIndex, string label, out NumericUpDown numeric, int min, int max, int value, string description)
        {
            layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            var title = new Label { Text = label, AutoSize = true, Margin = new Padding(0, 8, 8, 0) };
            numeric = new NumericUpDown { Minimum = min, Maximum = max, Value = value, Width = 90, Margin = new Padding(0, 4, 10, 0) };
            var help = CreateHelpLabel(description);
            help.Margin = new Padding(0, 6, 0, 0);
            layout.Controls.Add(title, 0, rowIndex);
            layout.Controls.Add(numeric, 1, rowIndex);
            layout.Controls.Add(help, 2, rowIndex);
        }

        private void AddToggleTimingRow(TableLayoutPanel layout, int rowIndex, string label, bool isChecked, out CheckBox checkBox, out NumericUpDown numeric, int min, int max, int value, string description)
        {
            layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            var localCheckBox = new CheckBox { Text = label, Checked = isChecked, AutoSize = true, Margin = new Padding(0, 6, 8, 0) };
            var localNumeric = new NumericUpDown { Minimum = min, Maximum = max, Value = value, Width = 90, Margin = new Padding(0, 4, 10, 0), Enabled = isChecked };
            localCheckBox.CheckedChanged += delegate { localNumeric.Enabled = localCheckBox.Checked; };
            var help = CreateHelpLabel(description);
            help.Margin = new Padding(0, 6, 0, 0);
            layout.Controls.Add(localCheckBox, 0, rowIndex);
            layout.Controls.Add(localNumeric, 1, rowIndex);
            layout.Controls.Add(help, 2, rowIndex);
            checkBox = localCheckBox;
            numeric = localNumeric;
        }

        private void AddDanceAttackRow(TableLayoutPanel layout, int rowIndex)
        {
            layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));

            _danceAttackEnabledCheckBox = new CheckBox { Text = "Dance Attack", Checked = false, AutoSize = true, Margin = new Padding(0, 4, 8, 0) };
            _danceMovingOnlyCheckBox = new CheckBox { Text = "Moving Targets Only", Checked = true, AutoSize = true, Margin = new Padding(24, 2, 8, 0) };
            _danceEveryAttackCheckBox = new CheckBox { Text = "Every Attack", Checked = false, AutoSize = true, Margin = new Padding(24, 2, 8, 0) };
            _danceMoveMsNumeric = new NumericUpDown { Minimum = 100, Maximum = 3000, Value = 600, Width = 90, Margin = new Padding(0, 2, 8, 0) };
            var help = CreateHelpLabel("Dance attack settings. The main checkbox enables dance attack behavior. Moving Targets Only limits it to moving enemies. Every Attack ignores the delay and moving-target-only settings.");
            help.Margin = new Padding(6, 4, 0, 0);

            _danceAttackEnabledCheckBox.CheckedChanged += delegate { UpdateDanceAttackControls(); };
            _danceEveryAttackCheckBox.CheckedChanged += delegate { UpdateDanceAttackControls(); };

            var outer = new TableLayoutPanel { Dock = DockStyle.Top, AutoSize = true, ColumnCount = 1, Margin = new Padding(0) };
            outer.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            outer.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            outer.RowStyles.Add(new RowStyle(SizeType.AutoSize));

            var topRow = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true, WrapContents = false, Margin = new Padding(0) };
            topRow.Controls.Add(_danceAttackEnabledCheckBox);
            topRow.Controls.Add(new Label { Text = "Delay (ms)", AutoSize = true, Margin = new Padding(10, 6, 8, 0) });
            topRow.Controls.Add(_danceMoveMsNumeric);
            topRow.Controls.Add(help);

            var subRow = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true, WrapContents = false, Margin = new Padding(0) };
            subRow.Controls.Add(_danceMovingOnlyCheckBox);

            var subRow2 = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true, WrapContents = false, Margin = new Padding(0) };
            subRow2.Controls.Add(_danceEveryAttackCheckBox);

            outer.Controls.Add(topRow, 0, 0);
            outer.Controls.Add(subRow, 0, 1);
            outer.Controls.Add(subRow2, 0, 2);

            layout.Controls.Add(outer, 0, rowIndex);
            layout.SetColumnSpan(outer, 3);

            UpdateDanceAttackControls();
        }

        private void UpdateDanceAttackControls()
        {
            if (_danceAttackEnabledCheckBox == null || _danceMovingOnlyCheckBox == null || _danceEveryAttackCheckBox == null || _danceMoveMsNumeric == null) return;
            var enabled = _danceAttackEnabledCheckBox.Checked;
            _danceMovingOnlyCheckBox.Enabled = enabled && _danceEveryAttackCheckBox.Checked == false;
            _danceEveryAttackCheckBox.Enabled = enabled;
            _danceMoveMsNumeric.Enabled = enabled && _danceEveryAttackCheckBox.Checked == false;
        }

        private void BuildTacticsTab(TabPage tab)
        {
            var root = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2, Padding = new Padding(12) };
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 100f));
            tab.Controls.Add(root);
            var options = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true, Margin = new Padding(0, 0, 0, 12) };
            root.Controls.Add(options, 0, 0);
            options.Controls.Add(new Label { Text = "Mode", AutoSize = true, Margin = new Padding(0, 6, 8, 0) });
            _modeComboBox = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 180 };
            _modeComboBox.Items.AddRange(new object[] { "Off", "Whitelist", "Blacklist" });
            _modeComboBox.SelectedIndex = 0;
            _modeComboBox.SelectedIndexChanged += delegate { UpdateTacticsModeView(); };
            options.Controls.Add(_modeComboBox);
            var upButton = new Button { Text = "Move Up", AutoSize = true, Margin = new Padding(12, 2, 0, 0) };
            upButton.Click += delegate { MoveSelectedRow(-1); };
            options.Controls.Add(upButton);
            var downButton = new Button { Text = "Move Down", AutoSize = true, Margin = new Padding(8, 2, 0, 0) };
            downButton.Click += delegate { MoveSelectedRow(1); };
            options.Controls.Add(downButton);
            var deleteButton = new Button { Text = "Delete Row", AutoSize = true, Margin = new Padding(8, 2, 0, 0) };
            deleteButton.Click += delegate { DeleteSelectedRow(); };
            options.Controls.Add(deleteButton);
            var sectionButton = new Button { Text = "Add Section", AutoSize = true, Margin = new Padding(8, 2, 0, 0) };
            sectionButton.Click += delegate { AddSectionRow(); };
            options.Controls.Add(sectionButton);

            var editorLayout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2 };
            editorLayout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            editorLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100f));
            root.Controls.Add(editorLayout, 0, 1);
            _activeListLabel = new Label { Text = "Whitelist Tactics", AutoSize = true, Margin = new Padding(0, 0, 0, 8) };
            editorLayout.Controls.Add(_activeListLabel, 0, 0);
            var panel = new Panel { Dock = DockStyle.Fill };
            editorLayout.Controls.Add(panel, 0, 1);
            _whitelistGrid = CreateGrid();
            _blacklistGrid = CreateGrid();
            _offLabel = new Label { Text = "Tactics is off", Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleCenter, Font = new Font("Segoe UI", 14f, FontStyle.Bold), Visible = false };
            panel.Controls.Add(_whitelistGrid);
            panel.Controls.Add(_blacklistGrid);
            panel.Controls.Add(_offLabel);
        }

        private void BuildHomunculusSkillsTab(TabPage tab)
        {
            var root = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2, Padding = new Padding(12) };
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 100f));
            tab.Controls.Add(root);
            root.Controls.Add(new Label { Text = "These defaults are lower priority than per-monster tactics. Vanilmirth settings are active right now; the other homunculus families are saved for future behavior work.", AutoSize = true, ForeColor = Color.FromArgb(70, 70, 70), Margin = new Padding(0, 0, 0, 12) }, 0, 0);
            var scrollPanel = new Panel { Dock = DockStyle.Fill, AutoScroll = true };
            root.Controls.Add(scrollPanel, 0, 1);
            var stack = new TableLayoutPanel { Dock = DockStyle.Top, AutoSize = true, ColumnCount = 1 };
            scrollPanel.Controls.Add(stack);
            foreach (var family in HomunculusFamilies) stack.Controls.Add(BuildHomunculusFamilyGroup(family));
        }

        private Control BuildHomunculusFamilyGroup(string family)
        {
            var group = new GroupBox { Text = family, Dock = DockStyle.Top, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, Margin = new Padding(0, 0, 0, 12), Padding = new Padding(12) };
            var skills = HomunculusSkillDefinitions.Where(d => string.Equals(d.Family, family, StringComparison.OrdinalIgnoreCase)).ToArray();
            var layout = new TableLayoutPanel { Dock = DockStyle.Top, AutoSize = true, ColumnCount = 3 };
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f));
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            group.Controls.Add(layout);
            layout.Controls.Add(new Label { Text = "Skill", AutoSize = true, Font = new Font("Segoe UI", 9f, FontStyle.Bold), Margin = new Padding(0, 0, 12, 8) }, 0, 0);
            layout.Controls.Add(new Label { Text = "Stop Using Below % SP", AutoSize = true, Font = new Font("Segoe UI", 9f, FontStyle.Bold), Margin = new Padding(0, 0, 12, 8) }, 1, 0);
            layout.Controls.Add(new Label { Text = "Default Level", AutoSize = true, Font = new Font("Segoe UI", 9f, FontStyle.Bold), Margin = new Padding(0, 0, 0, 8) }, 2, 0);
            var row = 1;
            for (var i = 0; i < skills.Length; i++)
            {
                var def = skills[i];
                layout.Controls.Add(new Label { Text = def.DisplayName, AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(0, 6, 12, 6) }, 0, row);
                var minSp = new NumericUpDown { Minimum = 0, Maximum = 100, Value = def.DefaultMinSPPercent, Width = 90, Anchor = AnchorStyles.Left, Margin = new Padding(0, 2, 12, 2) };
                layout.Controls.Add(minSp, 1, row);
                var level = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 90, Anchor = AnchorStyles.Left, Margin = new Padding(0, 2, 0, 2) };
                level.Items.AddRange(HomunculusSkillLevelOptions);
                level.SelectedItem = LevelToDisplay(def.DefaultLevel);
                layout.Controls.Add(level, 2, row);
                _homunculusSkillRows[BuildSkillStateKey(def.Family, def.SkillKey)] = new SkillEditorRow { MinSPPercent = minSp, Level = level };
                row++;

                if (string.Equals(def.Family, "Vanilmirth", StringComparison.OrdinalIgnoreCase) && string.Equals(def.SkillKey, "ChaoticBlessings", StringComparison.OrdinalIgnoreCase))
                {
                    layout.Controls.Add(new Label { Text = "    Cast When Owner HP % Is At Or Below", AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(0, 2, 12, 4) }, 0, row);
                    _chaoticBlessingsOwnerHpNumeric = new NumericUpDown { Minimum = 0, Maximum = 100, Value = 0, Width = 90, Anchor = AnchorStyles.Left, Margin = new Padding(0, 2, 12, 2) };
                    layout.Controls.Add(_chaoticBlessingsOwnerHpNumeric, 1, row);
                    layout.Controls.Add(new Label { Text = "0 = OFF", AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(0, 4, 0, 0), ForeColor = Color.FromArgb(110, 110, 110) }, 2, row);
                    row++;

                    layout.Controls.Add(new Label { Text = "    Cast When Homu HP % Is At Or Below", AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(0, 2, 12, 6) }, 0, row);
                    _chaoticBlessingsHomunHpNumeric = new NumericUpDown { Minimum = 0, Maximum = 100, Value = 0, Width = 90, Anchor = AnchorStyles.Left, Margin = new Padding(0, 2, 12, 2) };
                    layout.Controls.Add(_chaoticBlessingsHomunHpNumeric, 1, row);
                    layout.Controls.Add(new Label { Text = "0 = OFF", AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(0, 4, 0, 0), ForeColor = Color.FromArgb(110, 110, 110) }, 2, row);
                    row++;
                }
            }
            return group;
        }

        private DataGridView CreateGrid()
        {
            var grid = new BufferedDataGridView { Dock = DockStyle.Fill, AllowUserToAddRows = true, AllowUserToDeleteRows = false, AllowUserToResizeRows = false, AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill, BackgroundColor = SystemColors.Window, BorderStyle = BorderStyle.FixedSingle, EditMode = DataGridViewEditMode.EditOnEnter, MultiSelect = false, RowHeadersVisible = true, SelectionMode = DataGridViewSelectionMode.CellSelect };
            grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Section", Visible = false });
            grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "MobID", HeaderText = "Mob ID", FillWeight = 12f });
            grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "MonsterName", HeaderText = "Monster Name", FillWeight = 24f });
            var behavior = new DataGridViewComboBoxColumn { Name = "Behavior", HeaderText = "Behavior", FillWeight = 18f, FlatStyle = FlatStyle.Flat };
            behavior.Items.AddRange(TacticBehaviorOptions);
            grid.Columns.Add(behavior);
            var priority = new DataGridViewComboBoxColumn { Name = "Priority", HeaderText = "Priority", FillWeight = 12f, FlatStyle = FlatStyle.Flat };
            priority.Items.AddRange(TacticPriorityOptions);
            grid.Columns.Add(priority);
            var skill = new DataGridViewTextBoxColumn { Name = "Skill", HeaderText = "Skills", FillWeight = 12f };
            grid.Columns.Add(skill);
            var skillLevel = new DataGridViewComboBoxColumn { Name = "SkillLevel", HeaderText = "Skill Level", FillWeight = 12f, FlatStyle = FlatStyle.Flat };
            skillLevel.Items.AddRange(SkillLevelOptions);
            grid.Columns.Add(skillLevel);
            grid.CellClick += GridStartEdit;
            grid.CellEnter += GridStartEdit;
            grid.CurrentCellDirtyStateChanged += delegate(object sender, EventArgs e) { var current = (DataGridView)sender; if (current.IsCurrentCellDirty) current.CommitEdit(DataGridViewDataErrorContexts.Commit); };
            grid.KeyDown += delegate(object sender, KeyEventArgs e) { if (e.KeyCode == Keys.Delete) { DeleteSelectedRow((DataGridView)sender); e.Handled = true; } };
            grid.CellValueChanged += delegate(object sender, DataGridViewCellEventArgs e) { RefreshRowStyles((DataGridView)sender); MarkDirty(); };
            grid.RowsAdded += delegate(object sender, DataGridViewRowsAddedEventArgs e) { RefreshRowStyles((DataGridView)sender); MarkDirty(); };
            grid.RowsRemoved += delegate(object sender, DataGridViewRowsRemovedEventArgs e) { RefreshRowStyles((DataGridView)sender); MarkDirty(); };
            return grid;
        }

        private void GridStartEdit(object sender, DataGridViewCellEventArgs e) { if (e.RowIndex >= 0 && e.ColumnIndex >= 0) ((DataGridView)sender).BeginEdit(true); }

        private void HookDirtyTracking(Control parent)
        {
            foreach (Control control in parent.Controls)
            {
                if (!ReferenceEquals(control, _profileComboBox))
                {
                    var checkBox = control as CheckBox;
                    var numeric = control as NumericUpDown;
                    var comboBox = control as ComboBox;
                    var textBox = control as TextBox;

                    if (checkBox != null)
                    {
                        checkBox.CheckedChanged += delegate { MarkDirty(); };
                    }
                    else if (numeric != null)
                    {
                        numeric.ValueChanged += delegate { MarkDirty(); };
                    }
                    else if (comboBox != null)
                    {
                        comboBox.SelectedIndexChanged += delegate { MarkDirty(); };
                    }
                    else if (textBox != null)
                    {
                        textBox.TextChanged += delegate { MarkDirty(); };
                    }
                }

                if (control.HasChildren)
                {
                    HookDirtyTracking(control);
                }
            }
        }

        private void SetDirty(bool dirty)
        {
            _isDirty = dirty;
        }

        private void MarkDirty()
        {
            if (_loadingUi || _suppressProfileSelectionChanged) return;
            _isDirty = true;
        }

        private void MainForm_FormClosing(object sender, FormClosingEventArgs e)
        {
            if (_isDirty == false) return;

            var result = MessageBox.Show(this, "Overwrite Settings?", "Overwrite Settings?", MessageBoxButtons.YesNoCancel, MessageBoxIcon.Warning);
            if (result == DialogResult.Cancel)
            {
                e.Cancel = true;
                return;
            }

            if (result == DialogResult.Yes && SaveFile() == false)
            {
                e.Cancel = true;
            }
        }

        private void LoadFile()
        {
            try
            {
                if (!File.Exists(_targetListsPath)) { SetStatusMessage("File not found yet. Set your behavior and save to create it.", Color.FromArgb(70, 70, 70), false); return; }
                var text = File.ReadAllText(_targetListsPath);
                _behaviorComboBox.SelectedItem = ParseBehaviorMode(text);
                _modeComboBox.SelectedItem = ParseTacticsMode(text);
                PopulateGrid(_whitelistGrid, ParseEntries(text, "Whitelist"));
                PopulateGrid(_blacklistGrid, ParseEntries(text, "Blacklist"));
                ApplyHomunculusSkillSettings(ParseHomunculusSkillSettings(text));
                ApplyPatrolSettings(ParsePatrolSettings(text));
                ApplyRuntimeSettings(ParseRuntimeSettings(text));
                UpdateBehaviorDescription();
                UpdateTacticsModeView();
                SetStatusMessage("Loaded " + Path.GetFileName(_targetListsPath), Color.FromArgb(70, 70, 70), true);
                SetDirty(false);
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, ex.Message, "Load failed", MessageBoxButtons.OK, MessageBoxIcon.Error);
                SetStatusMessage("Load failed", Color.FromArgb(180, 45, 45), true);
            }
        }

        private bool SaveFile()
        {
            try
            {
                SaveCurrentEditorIntoActiveProfile();
                SaveProfiles();
                WriteTargetLists();
                SetStatusMessage("Saved " + Path.GetFileName(_targetListsPath), Color.FromArgb(28, 140, 64), true);
                SetDirty(false);
                return true;
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, ex.Message, "Save failed", MessageBoxButtons.OK, MessageBoxIcon.Error);
                SetStatusMessage("Save failed", Color.FromArgb(180, 45, 45), true);
                return false;
            }
        }

        private void CheckForUpdates()
        {
            if (_isDirty)
            {
                var saveResult = MessageBox.Show(this, "Save your settings before checking for updates?", "Save Settings?", MessageBoxButtons.YesNoCancel, MessageBoxIcon.Question);
                if (saveResult == DialogResult.Cancel) return;
                if (saveResult == DialogResult.Yes && SaveFile() == false) return;
            }

            if (MessageBox.Show(this, "Download updates from SleepySlepe/s7-lattice-notes?\n\nThe updater will only replace code/editor files and will not overwrite TargetLists.lua, profiles, or other settings.", "Check Updates", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes)
            {
                return;
            }

            try
            {
                SetStatusMessage("Checking for updates...", Color.FromArgb(70, 70, 70), false);
                var result = ApplyUpdatesFromManifest();
                if (result.EditorUpdatePending)
                {
                    SetStatusMessage("Update downloaded. Restarting editor...", Color.FromArgb(28, 140, 64), false);
                    LaunchSelfUpdateScript(result.PendingEditorPath);
                    Close();
                    return;
                }

                SetStatusMessage("Updated " + result.UpdatedCount + " file(s). Settings were preserved.", Color.FromArgb(28, 140, 64), true);
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, ex.Message, "Update failed", MessageBoxButtons.OK, MessageBoxIcon.Error);
                SetStatusMessage("Update failed", Color.FromArgb(180, 45, 45), true);
            }
        }

        private sealed class UpdateResult
        {
            public int UpdatedCount;
            public bool EditorUpdatePending;
            public string PendingEditorPath;
        }

        private UpdateResult ApplyUpdatesFromManifest()
        {
            using (var client = CreateUpdateWebClient())
            {
                string manifestUrl;
                var manifest = DownloadManifest(client, out manifestUrl);
                var rawBaseUrl = manifestUrl.Substring(0, manifestUrl.LastIndexOf('/') + 1);
                var result = new UpdateResult();

                if (manifest.Files == null || manifest.Files.Count == 0)
                {
                    throw new InvalidOperationException("The update manifest did not list any files.");
                }

                foreach (var updateFile in manifest.Files)
                {
                    var relativePath = NormalizeUpdatePath(updateFile != null ? updateFile.Path : null);
                    if (string.IsNullOrWhiteSpace(relativePath) || IsAllowedUpdateFile(relativePath) == false || IsProtectedUpdateFile(relativePath))
                    {
                        continue;
                    }

                    var destinationPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, relativePath);
                    EnsurePathStaysInAppDirectory(destinationPath);
                    var downloadUrl = rawBaseUrl + EscapeRawPath(relativePath);
                    var tempPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, ".update-" + Path.GetFileName(relativePath) + "-" + Guid.NewGuid().ToString("N") + ".tmp");
                    client.DownloadFile(downloadUrl, tempPath);

                    if (IsSelfExecutable(destinationPath))
                    {
                        var pendingPath = destinationPath + ".pending";
                        File.Copy(tempPath, pendingPath, true);
                        File.Delete(tempPath);
                        result.EditorUpdatePending = true;
                        result.PendingEditorPath = pendingPath;
                        result.UpdatedCount++;
                        continue;
                    }

                    BackupExistingFile(destinationPath);
                    File.Copy(tempPath, destinationPath, true);
                    File.Delete(tempPath);
                    result.UpdatedCount++;
                }

                return result;
            }
        }

        private WebClient CreateUpdateWebClient()
        {
            ServicePointManager.SecurityProtocol = ServicePointManager.SecurityProtocol | (SecurityProtocolType)3072;
            var client = new WebClient();
            client.Headers.Add("User-Agent", "SlepeAI-Settings-Updater");
            client.Headers.Add("Cache-Control", "no-cache");
            return client;
        }

        private UpdateManifest DownloadManifest(WebClient client, out string manifestUrl)
        {
            Exception lastError = null;
            foreach (var url in UpdateManifestUrls)
            {
                try
                {
                    var text = client.DownloadString(url);
                    var manifest = _serializer.Deserialize<UpdateManifest>(text);
                    if (manifest == null)
                    {
                        throw new InvalidOperationException("The update manifest was empty.");
                    }

                    manifestUrl = url;
                    return manifest;
                }
                catch (Exception ex)
                {
                    lastError = ex;
                }
            }

            throw new InvalidOperationException("Could not download update-manifest.json from GitHub.", lastError);
        }

        private static string NormalizeUpdatePath(string path)
        {
            if (string.IsNullOrWhiteSpace(path)) return "";
            return path.Replace('\\', '/').Trim().TrimStart('/');
        }

        private static bool IsAllowedUpdateFile(string relativePath)
        {
            return AllowedUpdateFiles.Any(file => string.Equals(file, relativePath, StringComparison.OrdinalIgnoreCase));
        }

        private static bool IsProtectedUpdateFile(string relativePath)
        {
            if (relativePath.EndsWith(".bak", StringComparison.OrdinalIgnoreCase)) return true;
            return ProtectedUpdateFiles.Any(file => string.Equals(file, relativePath, StringComparison.OrdinalIgnoreCase) || relativePath.StartsWith(file + "/", StringComparison.OrdinalIgnoreCase));
        }

        private static string EscapeRawPath(string relativePath)
        {
            return string.Join("/", relativePath.Split('/').Select(Uri.EscapeDataString).ToArray());
        }

        private static void EnsurePathStaysInAppDirectory(string path)
        {
            var basePath = Path.GetFullPath(AppDomain.CurrentDomain.BaseDirectory);
            var fullPath = Path.GetFullPath(path);
            if (fullPath.StartsWith(basePath, StringComparison.OrdinalIgnoreCase) == false)
            {
                throw new InvalidOperationException("Update path is outside the AI folder: " + path);
            }
        }

        private static bool IsSelfExecutable(string destinationPath)
        {
            return string.Equals(Path.GetFullPath(destinationPath), Path.GetFullPath(Application.ExecutablePath), StringComparison.OrdinalIgnoreCase);
        }

        private static void BackupExistingFile(string destinationPath)
        {
            if (File.Exists(destinationPath) == false) return;
            var backupPath = destinationPath + "." + DateTime.Now.ToString("yyyyMMddHHmmss") + ".bak";
            File.Copy(destinationPath, backupPath, true);
        }

        private static void LaunchSelfUpdateScript(string pendingEditorPath)
        {
            var exePath = Application.ExecutablePath;
            var scriptPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "ApplySlepeAIUpdate.cmd");
            var script = new StringBuilder();
            script.AppendLine("@echo off");
            script.AppendLine("ping 127.0.0.1 -n 2 > nul");
            script.AppendLine("copy /Y \"" + pendingEditorPath + "\" \"" + exePath + "\" > nul");
            script.AppendLine("del \"" + pendingEditorPath + "\" > nul 2> nul");
            script.AppendLine("start \"\" \"" + exePath + "\"");
            script.AppendLine("del \"%~f0\" > nul 2> nul");
            File.WriteAllText(scriptPath, script.ToString(), new UTF8Encoding(false));
            Process.Start(new ProcessStartInfo { FileName = scriptPath, WorkingDirectory = AppDomain.CurrentDomain.BaseDirectory, WindowStyle = ProcessWindowStyle.Hidden });
        }

        private void WriteTargetLists()
        {
            var text = BuildLua(GetBehaviorMode(), GetSelectedTacticsMode(), ReadEntries(_whitelistGrid), ReadEntries(_blacklistGrid), ReadHomunculusSkillSettings(), ReadPatrolSettings(), ReadRuntimeSettings());
            File.WriteAllText(_targetListsPath, text, new UTF8Encoding(false));
        }

        private void LoadProfiles(bool reloadStore = true)
        {
            if (reloadStore || _profileStore == null)
            {
                _profileStore = ReadProfileStore();
            }
            if (_profileStore.Profiles == null || _profileStore.Profiles.Count == 0)
            {
                var initial = CaptureCurrentSnapshot("Profile 1", Guid.NewGuid().ToString("N"));
                _profileStore.Profiles = new List<EditorProfileMeta> { new EditorProfileMeta { Id = initial.Id, Name = initial.Name } };
                WriteProfileSnapshot(initial);
                _profileStore.ActiveProfileId = initial.Id;
                _profileStore.AltTAction = "Standard Standby";
                _profileStore.AltTProfileId = initial.Id;
                SaveProfiles();
            }

            PopulateProfileSelectors();
            var active = GetActiveProfile();
            if (active != null) ApplySnapshot(active);
            UpdateAltTProfileState();
            SetDirty(false);
        }

        private EditorProfileStore ReadProfileStore()
        {
            try
            {
                if (File.Exists(_profilesPath))
                {
                    Directory.CreateDirectory(_profilesDirectory);
                    var raw = File.ReadAllText(_profilesPath, Encoding.UTF8);
                    var loaded = _serializer.Deserialize<EditorProfileStore>(raw);
                    if (loaded != null)
                    {
                        if (loaded.Profiles == null) loaded.Profiles = new List<EditorProfileMeta>();
                        if (string.IsNullOrWhiteSpace(loaded.AltTAction)) loaded.AltTAction = "Standard Standby";

                        var legacy = _serializer.Deserialize<LegacyEditorProfileStore>(raw);
                        if (legacy != null && legacy.Profiles != null)
                        {
                            foreach (var snapshot in legacy.Profiles)
                            {
                                if (snapshot == null || string.IsNullOrWhiteSpace(snapshot.Id)) continue;
                                if (!File.Exists(GetProfilePath(snapshot.Id)))
                                {
                                    WriteProfileSnapshot(NormalizeSnapshot(snapshot, snapshot.Name, snapshot.Id));
                                }

                                if (!loaded.Profiles.Any(p => string.Equals(p.Id, snapshot.Id, StringComparison.OrdinalIgnoreCase)))
                                {
                                    loaded.Profiles.Add(new EditorProfileMeta { Id = snapshot.Id, Name = string.IsNullOrWhiteSpace(snapshot.Name) ? "Profile" : snapshot.Name });
                                }
                            }
                        }

                        return loaded;
                    }
                }
            }
            catch
            {
            }

            return new EditorProfileStore { Profiles = new List<EditorProfileMeta>(), AltTAction = "Standard Standby" };
        }

        private void SaveProfiles()
        {
            if (_profileStore == null) return;
            Directory.CreateDirectory(_profilesDirectory);
            File.WriteAllText(_profilesPath, _serializer.Serialize(_profileStore), new UTF8Encoding(false));
        }

        private void PopulateProfileSelectors()
        {
            _suppressProfileSelectionChanged = true;
            _profileComboBox.Items.Clear();
            _altTProfileComboBox.Items.Clear();
            foreach (var profile in _profileStore.Profiles)
            {
                _profileComboBox.Items.Add(new ProfileListItem(profile.Id, profile.Name));
                _altTProfileComboBox.Items.Add(new ProfileListItem(profile.Id, profile.Name));
            }

            SelectProfileItem(_profileComboBox, _profileStore.ActiveProfileId);
            SelectProfileItem(_altTProfileComboBox, _profileStore.AltTProfileId ?? _profileStore.ActiveProfileId);
            var savedAction = Convert.ToString(_profileStore.AltTAction) ?? "Standard Standby";
            if (string.Equals(savedAction, "Quick Swap Profile", StringComparison.OrdinalIgnoreCase))
                _altTActionComboBox.SelectedItem = "Quick Swap Profile";
            else if (string.Equals(savedAction, "Do Nothing", StringComparison.OrdinalIgnoreCase))
                _altTActionComboBox.SelectedItem = "Do Nothing";
            else if (string.Equals(savedAction, "Refresh", StringComparison.OrdinalIgnoreCase))
                _altTActionComboBox.SelectedItem = "Refresh";
            else
                _altTActionComboBox.SelectedItem = "Standard Standby";
            _suppressProfileSelectionChanged = false;
        }

        private void SelectProfileItem(ComboBox comboBox, string profileId)
        {
            for (var i = 0; i < comboBox.Items.Count; i++)
            {
                var item = comboBox.Items[i] as ProfileListItem;
                if (item != null && string.Equals(item.Id, profileId, StringComparison.OrdinalIgnoreCase))
                {
                    comboBox.SelectedIndex = i;
                    return;
                }
            }

            if (comboBox.Items.Count > 0) comboBox.SelectedIndex = 0;
        }

        private string GetProfilePath(string profileId)
        {
            return Path.Combine(_profilesDirectory, (profileId ?? string.Empty) + ".json");
        }

        private EditorProfileSnapshot NormalizeSnapshot(EditorProfileSnapshot snapshot, string fallbackName, string fallbackId)
        {
            var normalized = snapshot ?? new EditorProfileSnapshot();
            normalized.Id = string.IsNullOrWhiteSpace(normalized.Id) ? fallbackId : normalized.Id;
            normalized.Name = string.IsNullOrWhiteSpace(normalized.Name) ? (string.IsNullOrWhiteSpace(fallbackName) ? "Profile" : fallbackName) : normalized.Name;
            normalized.BehaviorMode = NormalizeBehaviorMode(normalized.BehaviorMode);
            normalized.TacticsMode = NormalizeTacticsMode(normalized.TacticsMode);
            normalized.Whitelist = CloneEntries(normalized.Whitelist ?? new List<TacticEntry>());
            normalized.Blacklist = CloneEntries(normalized.Blacklist ?? new List<TacticEntry>());
            normalized.HomunculusSkills = CloneSkillSettings(normalized.HomunculusSkills ?? GetDefaultHomunculusSkillStates());
            normalized.Patrol = normalized.Patrol ?? new PatrolSettings { Enabled = false, Shape = "Square CW", Distance = 4 };
            normalized.Patrol.Shape = NormalizePatrolShape(normalized.Patrol.Shape);
            normalized.Patrol.Distance = ClampPatrolDistance(normalized.Patrol.Distance);
            normalized.Runtime = CloneRuntimeSettings(normalized.Runtime);
            return normalized;
        }

        private static bool SnapshotNeedsTacticMigration(EditorProfileSnapshot snapshot)
        {
            if (snapshot == null) return false;
            return EntriesNeedTacticMigration(snapshot.Whitelist) || EntriesNeedTacticMigration(snapshot.Blacklist);
        }

        private static bool EntriesNeedTacticMigration(List<TacticEntry> entries)
        {
            if (entries == null) return false;
            foreach (var entry in entries)
            {
                if (entry == null || entry.IsSection) continue;
                var normalized = NormalizeTacticEntry(entry);
                if (!string.Equals(entry.Behavior ?? string.Empty, normalized.Behavior ?? string.Empty, StringComparison.OrdinalIgnoreCase)) return true;
                if (!string.Equals(entry.Priority ?? string.Empty, normalized.Priority ?? string.Empty, StringComparison.OrdinalIgnoreCase)) return true;
            }
            return false;
        }

        private EditorProfileSnapshot ReadProfileSnapshot(string id, string fallbackName)
        {
            try
            {
                var path = GetProfilePath(id);
                if (File.Exists(path))
                {
                    var loaded = _serializer.Deserialize<EditorProfileSnapshot>(File.ReadAllText(path, Encoding.UTF8));
                    if (loaded != null)
                    {
                        var normalized = NormalizeSnapshot(loaded, fallbackName, id);
                        if (SnapshotNeedsTacticMigration(loaded))
                        {
                            File.WriteAllText(path, _serializer.Serialize(normalized), new UTF8Encoding(false));
                        }
                        return normalized;
                    }
                }
            }
            catch
            {
            }

            return NormalizeSnapshot(new EditorProfileSnapshot { Id = id, Name = fallbackName }, fallbackName, id);
        }

        private void WriteProfileSnapshot(EditorProfileSnapshot snapshot)
        {
            var normalized = NormalizeSnapshot(snapshot, snapshot != null ? snapshot.Name : "Profile", snapshot != null ? snapshot.Id : Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(_profilesDirectory);
            File.WriteAllText(GetProfilePath(normalized.Id), _serializer.Serialize(normalized), new UTF8Encoding(false));
        }

        private void DeleteProfileSnapshot(string id)
        {
            var path = GetProfilePath(id);
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }

        private EditorProfileMeta GetActiveProfileMeta()
        {
            if (_profileStore == null || _profileStore.Profiles == null) return null;
            var active = _profileStore.Profiles.FirstOrDefault(p => string.Equals(p.Id, _profileStore.ActiveProfileId, StringComparison.OrdinalIgnoreCase));
            return active ?? _profileStore.Profiles.FirstOrDefault();
        }

        private EditorProfileSnapshot GetActiveProfile()
        {
            var active = GetActiveProfileMeta();
            return active == null ? null : ReadProfileSnapshot(active.Id, active.Name);
        }

        private EditorProfileMeta GetSelectedProfileMeta()
        {
            var item = _profileComboBox.SelectedItem as ProfileListItem;
            if (item == null || _profileStore == null || _profileStore.Profiles == null) return null;
            return _profileStore.Profiles.FirstOrDefault(p => string.Equals(p.Id, item.Id, StringComparison.OrdinalIgnoreCase));
        }

        private EditorProfileSnapshot GetSelectedProfile()
        {
            var selected = GetSelectedProfileMeta();
            return selected == null ? null : ReadProfileSnapshot(selected.Id, selected.Name);
        }

        private void SaveCurrentEditorIntoActiveProfile()
        {
            var active = GetActiveProfileMeta();
            if (active == null) return;
            var snapshot = CaptureCurrentSnapshot(active.Name, active.Id);
            active.Name = snapshot.Name;
            WriteProfileSnapshot(snapshot);
            _profileStore.ActiveProfileId = active.Id;
            _profileStore.AltTAction = Convert.ToString(_altTActionComboBox.SelectedItem) ?? "Standard Standby";
            var altItem = _altTProfileComboBox.SelectedItem as ProfileListItem;
            _profileStore.AltTProfileId = altItem != null ? altItem.Id : active.Id;
        }

        private EditorProfileSnapshot CaptureCurrentSnapshot(string name, string id)
        {
            return new EditorProfileSnapshot
            {
                Id = id,
                Name = string.IsNullOrWhiteSpace(name) ? "Profile" : name,
                BehaviorMode = GetBehaviorMode(),
                TacticsMode = GetSelectedTacticsMode(),
                Whitelist = CloneEntries(ReadEntries(_whitelistGrid)),
                Blacklist = CloneEntries(ReadEntries(_blacklistGrid)),
                HomunculusSkills = CloneSkillSettings(ReadHomunculusSkillSettings()),
                Patrol = new PatrolSettings
                {
                    Enabled = _patrolEnabledCheckBox.Checked,
                    Shape = Convert.ToString(_patrolShapeComboBox.SelectedItem) ?? "Square CW",
                    Distance = (int)_patrolDistanceNumeric.Value
                },
                Runtime = CloneRuntimeSettings(ReadRuntimeSettings())
            };
        }

        private void ApplySnapshot(EditorProfileSnapshot snapshot)
        {
            if (snapshot == null) return;
            _suppressProfileSelectionChanged = true;
            _behaviorComboBox.SelectedItem = NormalizeBehaviorMode(snapshot.BehaviorMode);
            _modeComboBox.SelectedItem = NormalizeTacticsMode(snapshot.TacticsMode);
            PopulateGrid(_whitelistGrid, CloneEntries(snapshot.Whitelist ?? new List<TacticEntry>()));
            PopulateGrid(_blacklistGrid, CloneEntries(snapshot.Blacklist ?? new List<TacticEntry>()));
            ApplyHomunculusSkillSettings(CloneSkillSettings(snapshot.HomunculusSkills ?? GetDefaultHomunculusSkillStates()));
            _patrolEnabledCheckBox.Checked = snapshot.Patrol != null && snapshot.Patrol.Enabled;
            _patrolShapeComboBox.SelectedItem = NormalizePatrolShape(snapshot.Patrol != null ? snapshot.Patrol.Shape : "Square");
            _patrolDistanceNumeric.Value = ClampPatrolDistance(snapshot.Patrol != null ? snapshot.Patrol.Distance : 4);
            ApplyRuntimeSettings(CloneRuntimeSettings(snapshot.Runtime));
            _profileStore.ActiveProfileId = snapshot.Id;
            SelectProfileItem(_profileComboBox, snapshot.Id);
            UpdateBehaviorDescription();
            UpdateTacticsModeView();
            UpdateAltTProfileState();
            _suppressProfileSelectionChanged = false;
        }

        private void ApplySelectedProfile()
        {
            var selected = GetSelectedProfile();
            if (selected == null) return;
            ApplySnapshot(selected);
            SaveProfiles();
            WriteTargetLists();
            SetStatusMessage("Applied profile " + selected.Name + ".", Color.FromArgb(28, 140, 64), true);
            SetDirty(false);
        }

        private void CreateProfile()
        {
            SaveCurrentEditorIntoActiveProfile();
            var name = PromptForText(this, "Create Profile", "Profile name:", "Profile " + ((_profileStore.Profiles != null ? _profileStore.Profiles.Count : 0) + 1));
            if (string.IsNullOrWhiteSpace(name)) return;
            var snapshot = CaptureCurrentSnapshot(name.Trim(), Guid.NewGuid().ToString("N"));
            WriteProfileSnapshot(snapshot);
            _profileStore.Profiles.Add(new EditorProfileMeta { Id = snapshot.Id, Name = snapshot.Name });
            _profileStore.ActiveProfileId = snapshot.Id;
            PopulateProfileSelectors();
            ApplySnapshot(snapshot);
            SaveProfiles();
            WriteTargetLists();
            SetStatusMessage("Created profile " + snapshot.Name + ".", Color.FromArgb(28, 140, 64), true);
            SetDirty(false);
        }

        private void RenameProfile()
        {
            var selectedMeta = GetSelectedProfileMeta();
            if (selectedMeta == null) return;
            var selected = ReadProfileSnapshot(selectedMeta.Id, selectedMeta.Name);
            if (selected == null) return;
            var name = PromptForText(this, "Rename Profile", "Profile name:", selected.Name);
            if (string.IsNullOrWhiteSpace(name)) return;
            selected.Name = name.Trim();
            selectedMeta.Name = selected.Name;
            WriteProfileSnapshot(selected);
            PopulateProfileSelectors();
            SelectProfileItem(_profileComboBox, selected.Id);
            SaveProfiles();
            WriteTargetLists();
            SetStatusMessage("Renamed profile to " + selected.Name + ".", Color.FromArgb(28, 140, 64), true);
            SetDirty(false);
        }

        private void DeleteProfile()
        {
            var selectedMeta = GetSelectedProfileMeta();
            if (selectedMeta == null || _profileStore.Profiles == null || _profileStore.Profiles.Count <= 1) return;
            if (MessageBox.Show(this, "Delete profile \"" + selectedMeta.Name + "\"?", "Confirm Delete", MessageBoxButtons.YesNo, MessageBoxIcon.Warning) != DialogResult.Yes) return;
            _profileStore.Profiles.RemoveAll(p => string.Equals(p.Id, selectedMeta.Id, StringComparison.OrdinalIgnoreCase));
            DeleteProfileSnapshot(selectedMeta.Id);
            var replacement = _profileStore.Profiles.First();
            _profileStore.ActiveProfileId = replacement.Id;
            if (string.Equals(_profileStore.AltTProfileId, selectedMeta.Id, StringComparison.OrdinalIgnoreCase))
            {
                _profileStore.AltTProfileId = replacement.Id;
            }
            PopulateProfileSelectors();
            ApplySnapshot(ReadProfileSnapshot(replacement.Id, replacement.Name));
            SaveProfiles();
            WriteTargetLists();
            SetStatusMessage("Deleted profile " + selectedMeta.Name + ".", Color.FromArgb(28, 140, 64), true);
            SetDirty(false);
        }

        private void UpdateAltTProfileState()
        {
            if (_altTProfileComboBox == null || _altTActionComboBox == null) return;
            _altTProfileComboBox.Enabled = string.Equals(Convert.ToString(_altTActionComboBox.SelectedItem), "Quick Swap Profile", StringComparison.OrdinalIgnoreCase);
        }

        private void HandleProfileSelectionChanged()
        {
            if (_suppressProfileSelectionChanged) return;
            SaveCurrentEditorIntoActiveProfile();
            var selected = GetSelectedProfile();
            if (selected == null) return;
            ApplySnapshot(selected);
            SaveProfiles();
            WriteTargetLists();
            SetStatusMessage("Switched to profile " + selected.Name + ".", Color.FromArgb(28, 140, 64), true);
            SetDirty(false);
        }

        private static string ParseBehaviorMode(string text) { var match = Regex.Match(text, "TargetLists\\.BehaviorMode\\s*=\\s*[\"'](?<value>[^\"']+)[\"']", RegexOptions.IgnoreCase); return match.Success ? NormalizeBehaviorMode(match.Groups["value"].Value) : "Slepe Mode"; }
        private static string ParseTacticsMode(string text) { var match = Regex.Match(text, "TargetLists\\.Mode\\s*=\\s*[\"'](?<mode>off|whitelist|blacklist)[\"']", RegexOptions.IgnoreCase); return match.Success ? NormalizeTacticsMode(match.Groups["mode"].Value) : "Off"; }

        private static List<TacticEntry> ParseEntries(string text, string key)
        {
            var result = new List<TacticEntry>();
            var tableMatch = Regex.Match(text, "TargetLists\\." + Regex.Escape(key) + "\\s*=\\s*\\{(?<body>[\\s\\S]*?)\\n\\}", RegexOptions.IgnoreCase);
            if (!tableMatch.Success) return result;
            foreach (Match rowMatch in Regex.Matches(tableMatch.Groups["body"].Value, "\\{(?<row>[^\\{\\}]*)\\}"))
            {
                var row = rowMatch.Groups["row"].Value;
                var section = ParseStringField(row, "Section");
                var mobId = ParseIntField(row, "MobID", 0);
                if (mobId == 0) { if (!string.IsNullOrWhiteSpace(section)) result.Add(new TacticEntry { Section = section, IsSection = true, MonsterName = section, Skill = string.Empty, Behavior = string.Empty, Priority = string.Empty }); continue; }
                var behavior = ParseStringField(row, "Behavior");
                var priority = ParseStringField(row, "Priority");
                string legacyBehavior;
                string legacyPriority;
                SplitLegacyTacticBehaviorAndPriority(behavior, out legacyBehavior, out legacyPriority);
                behavior = NormalizeTacticBehaviorChoice(behavior);
                if (string.IsNullOrWhiteSpace(behavior)) behavior = legacyBehavior;
                priority = NormalizeTacticPriorityChoice(priority, behavior);
                if (string.IsNullOrWhiteSpace(priority)) priority = NormalizeTacticPriorityChoice(legacyPriority, behavior);
                result.Add(new TacticEntry { Section = string.Empty, IsSection = false, MobID = mobId, MonsterName = ParseStringField(row, "MonsterName"), Behavior = behavior, Priority = priority, Skill = ParseSkillCountField(row, "Skill", 0).ToString(), SkillLevel = ParseIntField(row, "SkillLevel", 0) });
            }
            return result;
        }

        private static Dictionary<string, HomunculusSkillState> ParseHomunculusSkillSettings(string text)
        {
            var result = GetDefaultHomunculusSkillStates();
            var body = ExtractAssignedTableBody(text, "TargetLists.HomunculusSkills");
            if (string.IsNullOrWhiteSpace(body)) return result;
            foreach (var family in HomunculusFamilies)
            {
                var familyBody = ExtractNamedTableBody(body, family);
                if (string.IsNullOrWhiteSpace(familyBody)) continue;
                foreach (var def in HomunculusSkillDefinitions.Where(item => string.Equals(item.Family, family, StringComparison.OrdinalIgnoreCase)))
                {
                    var skillBody = ExtractNamedTableBody(familyBody, def.SkillKey);
                    if (string.IsNullOrWhiteSpace(skillBody)) continue;
                    result[BuildSkillStateKey(def.Family, def.SkillKey)] = new HomunculusSkillState
                    {
                        MinSPPercent = ClampPercent(ParseIntField(skillBody, "MinSPPercent", def.DefaultMinSPPercent)),
                        Level = ClampLevel(ParseIntField(skillBody, "Level", def.DefaultLevel)),
                        OwnerHPPercent = ClampPercent(ParseIntField(skillBody, "OwnerHPPercent", 0)),
                        HomunHPPercent = ClampPercent(ParseIntField(skillBody, "HomunHPPercent", 0))
                    };
                }
            }
            return result;
        }

        private static PatrolSettings ParsePatrolSettings(string text)
        {
            var result = new PatrolSettings { Enabled = false, Shape = "Square CW", Distance = 4 };
            var body = ExtractAssignedTableBody(text, "TargetLists.Patrol");
            if (string.IsNullOrWhiteSpace(body)) return result;
            result.Enabled = Regex.IsMatch(body, "Enabled\\s*=\\s*true", RegexOptions.IgnoreCase);
            result.Shape = NormalizePatrolShape(ParseStringField(body, "Shape"));
            result.Distance = ClampPatrolDistance(ParseIntField(body, "Distance", 4));
            return result;
        }

        private static RuntimeSettings GetDefaultRuntimeSettings()
        {
            return new RuntimeSettings { DefendOwner = true, TurretStayOnCell = false, NoKS = true, KSMode = "No KS", AntiStuckEnabled = true, AntiStuckMs = 500, FollowOwnerOnMove = true, FollowOwnerDelayMs = 0, SoftResetMs = 400, OwnerResumeMs = 100, PostSkillWaitMs = 700, DanceAttackEnabled = false, DanceMovingOnly = true, DanceEveryAttack = false, DanceMoveMs = 600 };
        }

        private static RuntimeSettings ParseRuntimeSettings(string text)
        {
            var result = GetDefaultRuntimeSettings();
            var body = ExtractAssignedTableBody(text, "TargetLists.Runtime");
            if (string.IsNullOrWhiteSpace(body)) return result;
            result.DefendOwner = !Regex.IsMatch(body, "DefendOwner\\s*=\\s*false", RegexOptions.IgnoreCase);
            result.TurretStayOnCell = Regex.IsMatch(body, "TurretStayOnCell\\s*=\\s*true", RegexOptions.IgnoreCase);
            result.NoKS = !Regex.IsMatch(body, "NoKS\\s*=\\s*false", RegexOptions.IgnoreCase);
            var ksModeMatch = Regex.Match(body, "KSMode\\s*=\\s*[\"'](?<value>[^\"']+)[\"']", RegexOptions.IgnoreCase);
            result.KSMode = NormalizeKSMode(ksModeMatch.Success ? ksModeMatch.Groups["value"].Value : (result.NoKS != false ? "No KS" : "Full KS"));
            result.AntiStuckEnabled = !Regex.IsMatch(body, "AntiStuckEnabled\\s*=\\s*false", RegexOptions.IgnoreCase);
            result.AntiStuckMs = ClampRuntimeMs(ParseIntField(body, "AntiStuckMs", result.AntiStuckMs));
            result.FollowOwnerOnMove = !Regex.IsMatch(body, "FollowOwnerOnMove\\s*=\\s*false", RegexOptions.IgnoreCase);
            result.FollowOwnerDelayMs = ClampRuntimeMs(ParseIntField(body, "FollowOwnerDelayMs", result.FollowOwnerDelayMs));
            result.SoftResetMs = ClampRuntimeMs(ParseIntField(body, "SoftResetMs", result.SoftResetMs));
            result.OwnerResumeMs = ClampRuntimeMs(ParseIntField(body, "OwnerResumeMs", result.OwnerResumeMs));
            result.PostSkillWaitMs = ClampRuntimeMs(ParseIntField(body, "PostSkillWaitMs", result.PostSkillWaitMs));
            result.DanceAttackEnabled = Regex.IsMatch(body, "DanceAttackEnabled\\s*=\\s*true", RegexOptions.IgnoreCase);
            result.DanceMovingOnly = !Regex.IsMatch(body, "DanceMovingOnly\\s*=\\s*false", RegexOptions.IgnoreCase);
            result.DanceEveryAttack = Regex.IsMatch(body, "DanceEveryAttack\\s*=\\s*true", RegexOptions.IgnoreCase);
            result.DanceMoveMs = ClampRuntimeMs(ParseIntField(body, "DanceMoveMs", result.DanceMoveMs));
            return result;
        }

        private static string ExtractAssignedTableBody(string text, string assignment)
        {
            var match = Regex.Match(text, Regex.Escape(assignment) + "\\s*=\\s*\\{", RegexOptions.IgnoreCase);
            return match.Success ? ExtractTableBody(text, match.Index + match.Length - 1) : null;
        }

        private static string ExtractNamedTableBody(string text, string tableName)
        {
            var match = Regex.Match(text, "\\b" + Regex.Escape(tableName) + "\\b\\s*=\\s*\\{", RegexOptions.IgnoreCase);
            return match.Success ? ExtractTableBody(text, match.Index + match.Length - 1) : null;
        }

        private static string ExtractTableBody(string text, int openBraceIndex)
        {
            if (openBraceIndex < 0 || openBraceIndex >= text.Length || text[openBraceIndex] != '{') return null;
            var depth = 0;
            for (var i = openBraceIndex; i < text.Length; i++)
            {
                if (text[i] == '{') depth++;
                else if (text[i] == '}')
                {
                    depth--;
                    if (depth == 0) return text.Substring(openBraceIndex + 1, i - openBraceIndex - 1);
                }
            }
            return null;
        }

        private static string ParseStringField(string row, string field) { var match = Regex.Match(row, field + "\\s*=\\s*[\"'](?<value>[^\"']*)[\"']", RegexOptions.IgnoreCase); return match.Success ? match.Groups["value"].Value : string.Empty; }
        private static int ParseIntField(string row, string field, int defaultValue) { var match = Regex.Match(row, field + "\\s*=\\s*(\\d+)", RegexOptions.IgnoreCase); return match.Success ? int.Parse(match.Groups[1].Value) : defaultValue; }
        private static int ClampTacticSkillCount(int count) { if (count < 0) return 0; if (count > MaxTacticSkillCount) return MaxTacticSkillCount; return count; }
        private static int NormalizeLegacySkillCount(string value)
        {
            var normalized = (value ?? string.Empty).Trim();
            if (string.Equals(normalized, "No Skill", StringComparison.OrdinalIgnoreCase)) return 0;
            if (string.Equals(normalized, "One Skill", StringComparison.OrdinalIgnoreCase)) return 1;
            if (string.Equals(normalized, "Two Skills", StringComparison.OrdinalIgnoreCase)) return 2;
            if (string.Equals(normalized, "Max Skills", StringComparison.OrdinalIgnoreCase)) return MaxTacticSkillCount;
            return -1;
        }
        private static bool TryParseSkillCountText(string value, out int skillCount)
        {
            var normalized = (value ?? string.Empty).Trim();
            if (string.IsNullOrWhiteSpace(normalized))
            {
                skillCount = 0;
                return true;
            }

            int parsed;
            if (int.TryParse(normalized, out parsed))
            {
                if (parsed < 0) { skillCount = 0; return false; }
                skillCount = ClampTacticSkillCount(parsed);
                return true;
            }

            parsed = NormalizeLegacySkillCount(normalized);
            if (parsed >= 0)
            {
                skillCount = parsed;
                return true;
            }

            skillCount = 0;
            return false;
        }
        private static int ParseSkillCountField(string row, string field, int defaultValue)
        {
            var numeric = ParseIntField(row, field, int.MinValue);
            if (numeric != int.MinValue) return ClampTacticSkillCount(numeric);
            var text = ParseStringField(row, field);
            int parsed;
            if (TryParseSkillCountText(text, out parsed)) return parsed;
            return ClampTacticSkillCount(defaultValue);
        }
        private static string NormalizeSkillCountText(string value)
        {
            int parsed;
            return TryParseSkillCountText(value, out parsed) ? parsed.ToString() : "0";
        }

        private static void PopulateGrid(DataGridView grid, List<TacticEntry> entries)
        {
            grid.Rows.Clear();
            foreach (var entry in entries)
            {
                var normalized = NormalizeTacticEntry(entry);
                var index = grid.Rows.Add(
                    normalized.IsSection ? (normalized.Section ?? normalized.MonsterName ?? string.Empty) : string.Empty,
                    normalized.IsSection ? string.Empty : normalized.MobID.ToString(),
                    normalized.MonsterName ?? string.Empty,
                    normalized.IsSection ? string.Empty : NormalizeTacticBehaviorChoice(normalized.Behavior),
                    normalized.IsSection ? string.Empty : NormalizeTacticPriorityChoice(normalized.Priority, normalized.Behavior),
                    normalized.IsSection ? string.Empty : NormalizeSkillCountText(normalized.Skill),
                    (normalized.IsSection || normalized.SkillLevel <= 0) ? string.Empty : normalized.SkillLevel.ToString());
                ApplyRowStyle(grid.Rows[index]);
            }
            RefreshRowStyles(grid);
        }

        private static List<TacticEntry> ReadEntries(DataGridView grid)
        {
            var result = new List<TacticEntry>();
            var seen = new HashSet<int>();
            foreach (DataGridViewRow row in grid.Rows)
            {
                if (row.IsNewRow) continue;
                var section = Convert.ToString(row.Cells["Section"].Value);
                var mobIdText = Convert.ToString(row.Cells["MobID"].Value);
                var name = Convert.ToString(row.Cells["MonsterName"].Value);
                var behavior = Convert.ToString(row.Cells["Behavior"].Value);
                var priority = Convert.ToString(row.Cells["Priority"].Value);
                var skill = Convert.ToString(row.Cells["Skill"].Value);
                var skillLevelText = Convert.ToString(row.Cells["SkillLevel"].Value);
                if (string.IsNullOrWhiteSpace(section) && string.IsNullOrWhiteSpace(mobIdText) && string.IsNullOrWhiteSpace(name) && string.IsNullOrWhiteSpace(behavior) && string.IsNullOrWhiteSpace(priority) && string.IsNullOrWhiteSpace(skill) && string.IsNullOrWhiteSpace(skillLevelText)) continue;
                if (string.IsNullOrWhiteSpace(mobIdText))
                {
                    var label = !string.IsNullOrWhiteSpace(section) ? section : name;
                    if (string.IsNullOrWhiteSpace(label)) throw new InvalidOperationException("Section rows need a label.");
                    result.Add(new TacticEntry { Section = label.Trim(), MonsterName = label.Trim(), IsSection = true, Behavior = string.Empty, Priority = string.Empty, Skill = string.Empty });
                    continue;
                }
                int mobId;
                if (!int.TryParse(mobIdText.Trim(), out mobId) || mobId <= 0) throw new InvalidOperationException("Invalid Mob ID: " + mobIdText);
                int skillLevel = 0;
                if (!string.IsNullOrWhiteSpace(skillLevelText) && (!int.TryParse(skillLevelText.Trim(), out skillLevel) || skillLevel < 1 || skillLevel > 5)) throw new InvalidOperationException("Invalid Skill Level for Mob ID " + mobId + ": " + skillLevelText);
                int skillCount;
                if (!TryParseSkillCountText(skill, out skillCount)) throw new InvalidOperationException("Invalid Skills value for Mob ID " + mobId + ": " + skill);
                behavior = NormalizeTacticBehaviorChoice(behavior);
                priority = NormalizeTacticPriorityChoice(priority, behavior);
                if (seen.Add(mobId)) result.Add(new TacticEntry { Section = string.Empty, IsSection = false, MobID = mobId, MonsterName = (name ?? string.Empty).Trim(), Behavior = behavior, Priority = priority, Skill = skillCount.ToString(), SkillLevel = skillLevel });
            }
            return result;
        }

        private static Dictionary<string, HomunculusSkillState> GetDefaultHomunculusSkillStates()
        {
            var result = new Dictionary<string, HomunculusSkillState>(StringComparer.OrdinalIgnoreCase);
            foreach (var def in HomunculusSkillDefinitions) result[BuildSkillStateKey(def.Family, def.SkillKey)] = new HomunculusSkillState { MinSPPercent = def.DefaultMinSPPercent, Level = def.DefaultLevel, OwnerHPPercent = 0, HomunHPPercent = 0 };
            return result;
        }

        private void ApplyHomunculusSkillSettings(Dictionary<string, HomunculusSkillState> settings)
        {
            foreach (var def in HomunculusSkillDefinitions)
            {
                SkillEditorRow row;
                if (!_homunculusSkillRows.TryGetValue(BuildSkillStateKey(def.Family, def.SkillKey), out row)) continue;
                HomunculusSkillState state;
                if (!settings.TryGetValue(BuildSkillStateKey(def.Family, def.SkillKey), out state)) state = new HomunculusSkillState { MinSPPercent = def.DefaultMinSPPercent, Level = def.DefaultLevel, OwnerHPPercent = 0, HomunHPPercent = 0 };
                row.MinSPPercent.Value = ClampPercent(state.MinSPPercent);
                row.Level.SelectedItem = LevelToDisplay(ClampLevel(state.Level));
            }

            HomunculusSkillState chaotic;
            if (!settings.TryGetValue(BuildSkillStateKey("Vanilmirth", "ChaoticBlessings"), out chaotic)) chaotic = new HomunculusSkillState { MinSPPercent = 40, Level = 0, OwnerHPPercent = 0, HomunHPPercent = 0 };
            if (_chaoticBlessingsOwnerHpNumeric != null) _chaoticBlessingsOwnerHpNumeric.Value = ClampPercent(chaotic.OwnerHPPercent);
            if (_chaoticBlessingsHomunHpNumeric != null) _chaoticBlessingsHomunHpNumeric.Value = ClampPercent(chaotic.HomunHPPercent);
        }

        private void ApplyPatrolSettings(PatrolSettings settings)
        {
            var patrol = settings ?? new PatrolSettings { Enabled = false, Shape = "Square CW", Distance = 4 };
            _patrolEnabledCheckBox.Checked = patrol.Enabled;
            _patrolShapeComboBox.SelectedItem = NormalizePatrolShape(patrol.Shape);
            _patrolDistanceNumeric.Value = ClampPatrolDistance(patrol.Distance);
        }

        private void ApplyRuntimeSettings(RuntimeSettings settings)
        {
            var runtime = settings ?? GetDefaultRuntimeSettings();
            _defendOwnerCheckBox.Checked = runtime.DefendOwner;
            _turretStayOnCellCheckBox.Checked = runtime.TurretStayOnCell;
            _ksModeComboBox.SelectedItem = NormalizeKSMode(string.IsNullOrWhiteSpace(runtime.KSMode) ? (runtime.NoKS != false ? "No KS" : "Full KS") : runtime.KSMode);
            _antiStuckEnabledCheckBox.Checked = runtime.AntiStuckEnabled;
            _antiStuckMsNumeric.Value = ClampRuntimeMs(runtime.AntiStuckMs);
            _antiStuckMsNumeric.Enabled = _antiStuckEnabledCheckBox.Checked;
            _followOwnerOnMoveCheckBox.Checked = runtime.FollowOwnerOnMove;
            _followOwnerDelayMsNumeric.Value = ClampRuntimeMs(runtime.FollowOwnerDelayMs);
            _followOwnerDelayMsNumeric.Enabled = _followOwnerOnMoveCheckBox.Checked;
            _softResetMsNumeric.Value = ClampRuntimeMs(runtime.SoftResetMs);
            _ownerResumeMsNumeric.Value = ClampRuntimeMs(runtime.OwnerResumeMs);
            _postSkillWaitMsNumeric.Value = ClampRuntimeMs(runtime.PostSkillWaitMs);
            _danceAttackEnabledCheckBox.Checked = runtime.DanceAttackEnabled;
            _danceMovingOnlyCheckBox.Checked = runtime.DanceMovingOnly;
            _danceEveryAttackCheckBox.Checked = runtime.DanceEveryAttack;
            _danceMoveMsNumeric.Value = ClampRuntimeMs(runtime.DanceMoveMs);
            UpdateDanceAttackControls();
        }

        private Dictionary<string, HomunculusSkillState> ReadHomunculusSkillSettings()
        {
            var result = new Dictionary<string, HomunculusSkillState>(StringComparer.OrdinalIgnoreCase);
            foreach (var def in HomunculusSkillDefinitions)
            {
                SkillEditorRow row;
                if (!_homunculusSkillRows.TryGetValue(BuildSkillStateKey(def.Family, def.SkillKey), out row)) continue;
                var state = new HomunculusSkillState { MinSPPercent = ClampPercent((int)row.MinSPPercent.Value), Level = ClampLevel(DisplayToLevel(Convert.ToString(row.Level.SelectedItem))), OwnerHPPercent = 0, HomunHPPercent = 0 };
                if (string.Equals(def.Family, "Vanilmirth", StringComparison.OrdinalIgnoreCase) && string.Equals(def.SkillKey, "ChaoticBlessings", StringComparison.OrdinalIgnoreCase))
                {
                    state.OwnerHPPercent = _chaoticBlessingsOwnerHpNumeric != null ? ClampPercent((int)_chaoticBlessingsOwnerHpNumeric.Value) : 0;
                    state.HomunHPPercent = _chaoticBlessingsHomunHpNumeric != null ? ClampPercent((int)_chaoticBlessingsHomunHpNumeric.Value) : 0;
                }
                result[BuildSkillStateKey(def.Family, def.SkillKey)] = state;
            }
            return result;
        }

        private PatrolSettings ReadPatrolSettings()
        {
            return new PatrolSettings
            {
                Enabled = _patrolEnabledCheckBox.Checked,
                Shape = NormalizePatrolShape(Convert.ToString(_patrolShapeComboBox.SelectedItem)),
                Distance = ClampPatrolDistance((int)_patrolDistanceNumeric.Value)
            };
        }

        private RuntimeSettings ReadRuntimeSettings()
        {
            return new RuntimeSettings
            {
                DefendOwner = _defendOwnerCheckBox.Checked,
                TurretStayOnCell = _turretStayOnCellCheckBox.Checked,
                KSMode = NormalizeKSMode(Convert.ToString(_ksModeComboBox.SelectedItem)),
                NoKS = NormalizeKSMode(Convert.ToString(_ksModeComboBox.SelectedItem)) == "No KS",
                AntiStuckEnabled = _antiStuckEnabledCheckBox.Checked,
                AntiStuckMs = ClampRuntimeMs((int)_antiStuckMsNumeric.Value),
                FollowOwnerOnMove = _followOwnerOnMoveCheckBox.Checked,
                FollowOwnerDelayMs = ClampRuntimeMs((int)_followOwnerDelayMsNumeric.Value),
                SoftResetMs = ClampRuntimeMs((int)_softResetMsNumeric.Value),
                OwnerResumeMs = ClampRuntimeMs((int)_ownerResumeMsNumeric.Value),
                PostSkillWaitMs = ClampRuntimeMs((int)_postSkillWaitMsNumeric.Value),
                DanceAttackEnabled = _danceAttackEnabledCheckBox.Checked,
                DanceMovingOnly = _danceMovingOnlyCheckBox.Checked,
                DanceEveryAttack = _danceEveryAttackCheckBox.Checked,
                DanceMoveMs = ClampRuntimeMs((int)_danceMoveMsNumeric.Value)
            };
        }

        private void MoveSelectedRow(int direction)
        {
            var grid = ActiveGrid();
            if (grid == null || grid.CurrentCell == null) return;
            var source = grid.CurrentCell.RowIndex;
            var target = source + direction;
            if (source < 0 || target < 0 || source >= grid.Rows.Count || target >= grid.Rows.Count) return;
            if (grid.Rows[source].IsNewRow || grid.Rows[target].IsNewRow) return;
            var currentColumn = grid.CurrentCell.ColumnIndex;
            var a = CaptureRow(grid.Rows[source]);
            var b = CaptureRow(grid.Rows[target]);
            ApplyRow(grid.Rows[source], b);
            ApplyRow(grid.Rows[target], a);
            RefreshRowStyles(grid);
            grid.CurrentCell = grid.Rows[target].Cells[currentColumn];
        }

        private void AddSectionRow()
        {
            var grid = ActiveGrid();
            if (grid == null) return;
            var index = grid.Rows.Count - 1;
            if (grid.CurrentCell != null && grid.CurrentCell.RowIndex >= 0 && grid.CurrentCell.RowIndex < grid.Rows.Count - 1) index = grid.CurrentCell.RowIndex + 1;
            grid.Rows.Insert(index, "new_map", string.Empty, "new_map", string.Empty, string.Empty, string.Empty, string.Empty);
            RefreshRowStyles(grid);
            grid.CurrentCell = grid.Rows[index].Cells["MonsterName"];
            grid.BeginEdit(true);
        }

        private void DeleteSelectedRow() { DeleteSelectedRow(ActiveGrid()); }

        private void DeleteSelectedRow(DataGridView grid)
        {
            if (grid == null || grid.CurrentCell == null) return;
            var index = grid.CurrentCell.RowIndex;
            if (index < 0 || index >= grid.Rows.Count || grid.Rows[index].IsNewRow) return;
            grid.Rows.RemoveAt(index);
            RefreshRowStyles(grid);
        }

        private DataGridView ActiveGrid() { if (_whitelistGrid.Visible) return _whitelistGrid; if (_blacklistGrid.Visible) return _blacklistGrid; return null; }
        private static object[] CaptureRow(DataGridViewRow row) { return new object[] { row.Cells["Section"].Value, row.Cells["MobID"].Value, row.Cells["MonsterName"].Value, row.Cells["Behavior"].Value, row.Cells["Priority"].Value, row.Cells["Skill"].Value, row.Cells["SkillLevel"].Value }; }
        private static void ApplyRow(DataGridViewRow row, object[] values) { row.Cells["Section"].Value = values[0]; row.Cells["MobID"].Value = values[1]; row.Cells["MonsterName"].Value = values[2]; row.Cells["Behavior"].Value = values[3]; row.Cells["Priority"].Value = values[4]; row.Cells["Skill"].Value = values[5]; row.Cells["SkillLevel"].Value = values[6]; ApplyRowStyle(row); }
        private static void RefreshRowStyles(DataGridView grid) { foreach (DataGridViewRow row in grid.Rows) if (!row.IsNewRow) ApplyRowStyle(row); }
        private static void ApplyRowStyle(DataGridViewRow row) { var section = Convert.ToString(row.Cells["Section"].Value); var mobId = Convert.ToString(row.Cells["MobID"].Value); var isSection = !string.IsNullOrWhiteSpace(section) && string.IsNullOrWhiteSpace(mobId); row.DefaultCellStyle.BackColor = isSection ? Color.FromArgb(238, 244, 252) : SystemColors.Window; row.DefaultCellStyle.Font = new Font("Segoe UI", 9f, isSection ? FontStyle.Bold : FontStyle.Regular); row.Cells["Behavior"].ReadOnly = isSection; row.Cells["Priority"].ReadOnly = isSection; row.Cells["Skill"].ReadOnly = isSection; row.Cells["SkillLevel"].ReadOnly = isSection; }

        private void UpdateBehaviorDescription()
        {
            var mode = GetBehaviorMode();
            if (mode == "Snipe") _behaviorDescriptionLabel.Text = "Snipe\n\nLong-range spell behavior. The homunculus tries to work from Caprice range, avoids normal melee attacking, and backs off to standby when nothing is in spell range.";
            else if (mode == "Avoid") _behaviorDescriptionLabel.Text = "Avoid\n\nNon-combat behavior. The homunculus avoids engaging and tries to stay away from threatening mobs instead of committing to normal attacks.";
            else if (mode == "React") _behaviorDescriptionLabel.Text = "React\n\nResponse-first behavior. The homunculus focuses on mobs that are involved with you, the homunculus itself, or your current target, instead of freely farming everything around it.";
            else if (mode == "Attack") _behaviorDescriptionLabel.Text = "Attack\n\nStraight aggressive behavior. The homunculus commits to normal attacks, and when skills are allowed it can use Caprice directly on the target it is currently fighting.";
            else _behaviorDescriptionLabel.Text = "Slepe Mode\n\nYour custom preferred behavior. This is the special mode with your tuned rules: skill-heavy openers, custom post-skill handoff logic, owner-protection peel behavior, anti-idle recovery, and the rule that once a mob has already been normally attacked it should stop receiving Slepe-style repeat skill behavior unless tactics explicitly override it.";
        }

        private void UpdateTacticsModeView()
        {
            var mode = GetSelectedTacticsMode();
            _whitelistGrid.Visible = false;
            _blacklistGrid.Visible = false;
            _offLabel.Visible = false;
            if (mode == "Whitelist") { _activeListLabel.Text = "Whitelist Tactics"; _whitelistGrid.Visible = true; }
            else if (mode == "Blacklist") { _activeListLabel.Text = "Blacklist Tactics"; _blacklistGrid.Visible = true; }
            else { _activeListLabel.Text = "Tactics"; _offLabel.Visible = true; }
        }

        private string GetBehaviorMode() { return NormalizeBehaviorMode(Convert.ToString(_behaviorComboBox.SelectedItem)); }
        private string GetSelectedTacticsMode() { return NormalizeTacticsMode(Convert.ToString(_modeComboBox.SelectedItem)); }
        private static string NormalizeBehaviorMode(string value) { foreach (var option in BehaviorOptions) if (string.Equals(option, value, StringComparison.OrdinalIgnoreCase)) return option; return "Slepe Mode"; }
        private static string NormalizeTacticsMode(string value) { if (string.Equals(value, "Whitelist", StringComparison.OrdinalIgnoreCase)) return "Whitelist"; if (string.Equals(value, "Blacklist", StringComparison.OrdinalIgnoreCase)) return "Blacklist"; return "Off"; }
        private static string NormalizeKSMode(string value) { foreach (var option in KsModeOptions) if (string.Equals(option, value, StringComparison.OrdinalIgnoreCase)) return option; return "No KS"; }
        private static string NormalizePatrolShape(string value)
        {
            var text = (value ?? string.Empty).Trim();
            if (string.Equals(text, "Square", StringComparison.OrdinalIgnoreCase) || string.Equals(text, "Square CW", StringComparison.OrdinalIgnoreCase)) return "Square CW";
            if (string.Equals(text, "Square CCW", StringComparison.OrdinalIgnoreCase)) return "Square CCW";
            if (string.Equals(text, "Diamond", StringComparison.OrdinalIgnoreCase) || string.Equals(text, "Diamond CW", StringComparison.OrdinalIgnoreCase)) return "Diamond CW";
            if (string.Equals(text, "Diamond CCW", StringComparison.OrdinalIgnoreCase)) return "Diamond CCW";
            if (string.Equals(text, "Circle", StringComparison.OrdinalIgnoreCase) || string.Equals(text, "Circle CW", StringComparison.OrdinalIgnoreCase)) return "Circle CW";
            if (string.Equals(text, "Circle CCW", StringComparison.OrdinalIgnoreCase)) return "Circle CCW";
            return "Square CW";
        }
        private static string NormalizeChoice(string value, string[] options) { var trimmed = (value ?? string.Empty).Trim(); foreach (var option in options) if (string.Equals(option, trimmed, StringComparison.OrdinalIgnoreCase)) return option; return options.Length > 0 ? options[0] : string.Empty; }
        private static TacticEntry NormalizeTacticEntry(TacticEntry entry)
        {
            if (entry == null) return new TacticEntry { Section = string.Empty, IsSection = false, Behavior = string.Empty, Priority = string.Empty, Skill = "0", SkillLevel = 0 };
            if (entry.IsSection)
            {
                return new TacticEntry
                {
                    Section = entry.Section,
                    IsSection = true,
                    MobID = entry.MobID,
                    MonsterName = entry.MonsterName,
                    Behavior = string.Empty,
                    Priority = string.Empty,
                    Skill = string.Empty,
                    SkillLevel = entry.SkillLevel
                };
            }

            string legacyBehavior;
            string legacyPriority;
            SplitLegacyTacticBehaviorAndPriority(entry.Behavior, out legacyBehavior, out legacyPriority);

            var behavior = NormalizeTacticBehaviorChoice(entry.Behavior);
            if (string.IsNullOrWhiteSpace(behavior)) behavior = legacyBehavior;

            var priority = NormalizeTacticPriorityChoice(entry.Priority, behavior);
            if (string.IsNullOrWhiteSpace(priority)) priority = NormalizeTacticPriorityChoice(legacyPriority, behavior);

            return new TacticEntry
            {
                Section = entry.Section,
                IsSection = false,
                MobID = entry.MobID,
                MonsterName = entry.MonsterName,
                Behavior = behavior,
                Priority = priority,
                Skill = NormalizeSkillCountText(entry.Skill),
                SkillLevel = entry.SkillLevel
            };
        }
        private static bool BehaviorSupportsPriority(string behavior)
        {
            var normalized = NormalizeTacticBehaviorChoice(behavior);
            return normalized == "Slepe Mode" || normalized == "Snipe" || normalized == "Attack" || normalized == "React";
        }
        private static void SplitLegacyTacticBehaviorAndPriority(string value, out string behavior, out string priority)
        {
            var normalized = (value ?? string.Empty).Trim();
            behavior = string.Empty;
            priority = string.Empty;

            if (string.Equals(normalized, "Slepe First", StringComparison.OrdinalIgnoreCase)) { behavior = "Slepe Mode"; priority = "First"; return; }
            if (string.Equals(normalized, "Slepe Last", StringComparison.OrdinalIgnoreCase)) { behavior = "Slepe Mode"; priority = "Last"; return; }
            if (string.Equals(normalized, "Slepe", StringComparison.OrdinalIgnoreCase) || string.Equals(normalized, "Slepe Mode", StringComparison.OrdinalIgnoreCase)) { behavior = "Slepe Mode"; priority = "Normal"; return; }
            if (string.Equals(normalized, "Snipe First", StringComparison.OrdinalIgnoreCase)) { behavior = "Snipe"; priority = "First"; return; }
            if (string.Equals(normalized, "Snipe Last", StringComparison.OrdinalIgnoreCase)) { behavior = "Snipe"; priority = "Last"; return; }
            if (string.Equals(normalized, "Snipe", StringComparison.OrdinalIgnoreCase)) { behavior = "Snipe"; priority = "Normal"; return; }
            if (string.Equals(normalized, "Attack First", StringComparison.OrdinalIgnoreCase)) { behavior = "Attack"; priority = "First"; return; }
            if (string.Equals(normalized, "Attack Last", StringComparison.OrdinalIgnoreCase)) { behavior = "Attack"; priority = "Last"; return; }
            if (string.Equals(normalized, "Attack", StringComparison.OrdinalIgnoreCase)) { behavior = "Attack"; priority = "Normal"; return; }
            if (string.Equals(normalized, "React First", StringComparison.OrdinalIgnoreCase)) { behavior = "React"; priority = "First"; return; }
            if (string.Equals(normalized, "React Last", StringComparison.OrdinalIgnoreCase)) { behavior = "React"; priority = "Last"; return; }
            if (string.Equals(normalized, "React", StringComparison.OrdinalIgnoreCase)) { behavior = "React"; priority = "Normal"; return; }
            if (string.Equals(normalized, "Avoid", StringComparison.OrdinalIgnoreCase)) { behavior = "Avoid"; return; }
            if (string.Equals(normalized, "Kite Away", StringComparison.OrdinalIgnoreCase) || string.Equals(normalized, "Kite Attack", StringComparison.OrdinalIgnoreCase)) { behavior = "Kite Attack"; return; }
            if (string.Equals(normalized, "Kite No Attack", StringComparison.OrdinalIgnoreCase)) { behavior = "Kite No Attack"; return; }
        }
        private static string NormalizeTacticBehaviorChoice(string value)
        {
            var normalized = NormalizeChoice(value, TacticBehaviorOptions);
            if (!string.IsNullOrWhiteSpace(normalized)) return normalized;
            string behavior;
            string priority;
            SplitLegacyTacticBehaviorAndPriority(value, out behavior, out priority);
            return behavior;
        }
        private static string NormalizeTacticPriorityChoice(string value, string behavior)
        {
            if (!BehaviorSupportsPriority(behavior)) return string.Empty;
            var normalized = NormalizeChoice(value, TacticPriorityOptions);
            if (!string.IsNullOrWhiteSpace(normalized)) return normalized;
            string legacyBehavior;
            string legacyPriority;
            SplitLegacyTacticBehaviorAndPriority(value, out legacyBehavior, out legacyPriority);
            if (!string.IsNullOrWhiteSpace(legacyPriority)) return legacyPriority;
            return "Normal";
        }
        private static string LevelToDisplay(int level) { return level < 1 ? "OFF" : "Lv" + level; }
        private static int DisplayToLevel(string value) { var match = Regex.Match((value ?? string.Empty).Trim(), "(\\d+)"); return match.Success ? ClampLevel(int.Parse(match.Groups[1].Value)) : 0; }
        private static int ClampLevel(int level) { if (level < 0) return 0; if (level > 5) return 5; return level; }
        private static int ClampPercent(int value) { if (value < 0) return 0; if (value > 100) return 100; return value; }
        private static int ClampPatrolDistance(int value) { if (value < 1) return 1; if (value > 12) return 12; return value; }
        private static int ClampRuntimeMs(int value) { if (value < 0) return 0; if (value > 10000) return 10000; return value; }
        private static string BuildSkillStateKey(string family, string skillKey) { return family + "." + skillKey; }
        private static List<TacticEntry> CloneEntries(List<TacticEntry> entries) { return (entries ?? new List<TacticEntry>()).Select(entry => NormalizeTacticEntry(entry)).ToList(); }
        private static Dictionary<string, HomunculusSkillState> CloneSkillSettings(Dictionary<string, HomunculusSkillState> settings) { var result = new Dictionary<string, HomunculusSkillState>(StringComparer.OrdinalIgnoreCase); if (settings == null) return result; foreach (var pair in settings) result[pair.Key] = new HomunculusSkillState { MinSPPercent = pair.Value.MinSPPercent, Level = pair.Value.Level, OwnerHPPercent = pair.Value.OwnerHPPercent, HomunHPPercent = pair.Value.HomunHPPercent }; return result; }
        private static RuntimeSettings CloneRuntimeSettings(RuntimeSettings settings) { var value = settings ?? GetDefaultRuntimeSettings(); var ksMode = NormalizeKSMode(string.IsNullOrWhiteSpace(value.KSMode) ? (value.NoKS == false ? "Full KS" : "No KS") : value.KSMode); return new RuntimeSettings { DefendOwner = value.DefendOwner, TurretStayOnCell = value.TurretStayOnCell, NoKS = ksMode == "No KS", KSMode = ksMode, AntiStuckEnabled = value.AntiStuckEnabled, AntiStuckMs = ClampRuntimeMs(value.AntiStuckMs), FollowOwnerOnMove = value.FollowOwnerOnMove, FollowOwnerDelayMs = ClampRuntimeMs(value.FollowOwnerDelayMs), SoftResetMs = ClampRuntimeMs(value.SoftResetMs), OwnerResumeMs = ClampRuntimeMs(value.OwnerResumeMs), PostSkillWaitMs = ClampRuntimeMs(value.PostSkillWaitMs), DanceAttackEnabled = value.DanceAttackEnabled, DanceMovingOnly = value.DanceMovingOnly, DanceEveryAttack = value.DanceEveryAttack, DanceMoveMs = ClampRuntimeMs(value.DanceMoveMs) }; }
        private static string PromptForText(IWin32Window owner, string title, string prompt, string initialValue)
        {
            using (var form = new Form())
            {
                form.Text = title;
                form.StartPosition = FormStartPosition.CenterParent;
                form.FormBorderStyle = FormBorderStyle.FixedDialog;
                form.MinimizeBox = false;
                form.MaximizeBox = false;
                form.ClientSize = new Size(420, 130);
                var label = new Label { Left = 12, Top = 12, Width = 390, Text = prompt };
                var textBox = new TextBox { Left = 12, Top = 38, Width = 390, Text = initialValue ?? string.Empty };
                var ok = new Button { Text = "OK", DialogResult = DialogResult.OK, Left = 246, Width = 75, Top = 82 };
                var cancel = new Button { Text = "Cancel", DialogResult = DialogResult.Cancel, Left = 327, Width = 75, Top = 82 };
                form.Controls.Add(label);
                form.Controls.Add(textBox);
                form.Controls.Add(ok);
                form.Controls.Add(cancel);
                form.AcceptButton = ok;
                form.CancelButton = cancel;
                return form.ShowDialog(owner) == DialogResult.OK ? textBox.Text : null;
            }
        }

        private static string BuildLua(string behaviorMode, string tacticsMode, List<TacticEntry> whitelist, List<TacticEntry> blacklist, Dictionary<string, HomunculusSkillState> homunculusSkillSettings, PatrolSettings patrolSettings, RuntimeSettings runtimeSettings)
        {
            var builder = new StringBuilder();
            builder.AppendLine("TargetLists = {}");
            builder.AppendLine();
            builder.AppendLine("TargetLists.BehaviorMode = \"" + EscapeLua(behaviorMode) + "\"");
            builder.AppendLine("TargetLists.Mode = \"" + tacticsMode.ToLowerInvariant() + "\"");
            builder.AppendLine("TargetLists.UseWhitelist = " + (tacticsMode == "Whitelist" ? "true" : "false"));
            builder.AppendLine("TargetLists.UseBlacklist = " + (tacticsMode == "Blacklist" ? "true" : "false"));
            builder.AppendLine();
            builder.AppendLine("TargetLists.Patrol = { Enabled = " + ((patrolSettings != null && patrolSettings.Enabled) ? "true" : "false") + ", Shape = \"" + EscapeLua(NormalizePatrolShape(patrolSettings != null ? patrolSettings.Shape : "Square CW")) + "\", Distance = " + ClampPatrolDistance(patrolSettings != null ? patrolSettings.Distance : 4) + " }");
            runtimeSettings = CloneRuntimeSettings(runtimeSettings);
            builder.AppendLine("TargetLists.Runtime = { DefendOwner = " + (runtimeSettings.DefendOwner ? "true" : "false") + ", TurretStayOnCell = " + (runtimeSettings.TurretStayOnCell ? "true" : "false") + ", KSMode = \"" + EscapeLua(NormalizeKSMode(runtimeSettings.KSMode)) + "\", NoKS = " + (NormalizeKSMode(runtimeSettings.KSMode) == "No KS" ? "true" : "false") + ", AntiStuckEnabled = " + (runtimeSettings.AntiStuckEnabled ? "true" : "false") + ", AntiStuckMs = " + runtimeSettings.AntiStuckMs + ", FollowOwnerOnMove = " + (runtimeSettings.FollowOwnerOnMove ? "true" : "false") + ", FollowOwnerDelayMs = " + runtimeSettings.FollowOwnerDelayMs + ", SoftResetMs = " + runtimeSettings.SoftResetMs + ", OwnerResumeMs = " + runtimeSettings.OwnerResumeMs + ", PostSkillWaitMs = " + runtimeSettings.PostSkillWaitMs + ", DanceAttackEnabled = " + (runtimeSettings.DanceAttackEnabled ? "true" : "false") + ", DanceMovingOnly = " + (runtimeSettings.DanceMovingOnly ? "true" : "false") + ", DanceEveryAttack = " + (runtimeSettings.DanceEveryAttack ? "true" : "false") + ", DanceMoveMs = " + runtimeSettings.DanceMoveMs + " }");
            builder.AppendLine();
            builder.AppendLine("TargetLists.HomunculusSkills = {");
            AppendHomunculusSkills(builder, homunculusSkillSettings);
            builder.AppendLine("}");
            builder.AppendLine();
            builder.AppendLine("TargetLists.Whitelist = {");
            AppendEntries(builder, whitelist);
            builder.AppendLine("}");
            builder.AppendLine();
            builder.AppendLine("TargetLists.Blacklist = {");
            AppendEntries(builder, blacklist);
            builder.AppendLine("}");
            return builder.ToString();
        }

        private static void AppendHomunculusSkills(StringBuilder builder, Dictionary<string, HomunculusSkillState> settings)
        {
            foreach (var family in HomunculusFamilies)
            {
                builder.AppendLine("    " + family + " = {");
                foreach (var def in HomunculusSkillDefinitions.Where(item => string.Equals(item.Family, family, StringComparison.OrdinalIgnoreCase)))
                {
                    HomunculusSkillState state;
                    if (!settings.TryGetValue(BuildSkillStateKey(def.Family, def.SkillKey), out state)) state = new HomunculusSkillState { MinSPPercent = def.DefaultMinSPPercent, Level = def.DefaultLevel, OwnerHPPercent = 0, HomunHPPercent = 0 };
                    var line = new StringBuilder();
                    line.Append("        ").Append(def.SkillKey).Append(" = { MinSPPercent = ").Append(ClampPercent(state.MinSPPercent)).Append(", Level = ").Append(ClampLevel(state.Level));
                    if (string.Equals(def.Family, "Vanilmirth", StringComparison.OrdinalIgnoreCase) && string.Equals(def.SkillKey, "ChaoticBlessings", StringComparison.OrdinalIgnoreCase))
                    {
                        line.Append(", OwnerHPPercent = ").Append(ClampPercent(state.OwnerHPPercent));
                        line.Append(", HomunHPPercent = ").Append(ClampPercent(state.HomunHPPercent));
                    }
                    line.Append(" },");
                    builder.AppendLine(line.ToString());
                }
                builder.AppendLine("    },");
            }
        }

        private static void AppendEntries(StringBuilder builder, List<TacticEntry> entries)
        {
            foreach (var entry in entries)
            {
                if (entry.IsSection) { builder.AppendLine("    { Section = \"" + EscapeLua(entry.Section) + "\" },"); continue; }
                var line = new StringBuilder();
                line.Append("    { MobID = ").Append(entry.MobID);
                line.Append(", MonsterName = \"").Append(EscapeLua(entry.MonsterName ?? string.Empty)).Append("\"");
                var behavior = NormalizeTacticBehaviorChoice(entry.Behavior);
                if (string.IsNullOrWhiteSpace(behavior)) behavior = "Attack";
                var priority = NormalizeTacticPriorityChoice(entry.Priority, behavior);
                line.Append(", Behavior = \"").Append(EscapeLua(behavior)).Append("\"");
                line.Append(", Priority = \"").Append(EscapeLua(priority)).Append("\"");
                line.Append(", Skill = ").Append(NormalizeSkillCountText(entry.Skill));
                line.Append(", SkillLevel = ").Append(entry.SkillLevel);
                line.Append(" },");
                builder.AppendLine(line.ToString());
            }
        }

        private static string EscapeLua(string value) { return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\""); }
    }
}
