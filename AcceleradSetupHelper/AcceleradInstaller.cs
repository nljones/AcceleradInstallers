using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.Configuration.Install;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text;
using System.Threading.Tasks;

using Microsoft.Win32;


namespace AcceleradSetupHelper
{
    /// <summary>
    /// Instaler helper for Accelerad.
    /// Based on http://askville.amazon.com/append-directory-PATH-environment-variable-Visual-Studio-Deployment-installation-Project/AnswerViewer.do?requestId=4628663
    /// </summary>
    [RunInstaller(true)]
    public class AcceleradInstaller : Installer
    {
        /// <summary>
        /// The path to the installation folder (also the folder containing this assembly).
        /// </summary>
        private static string InstallPath
        {
            get
            {
                string myFile = System.Reflection.Assembly.GetExecutingAssembly().Location;
                string myPath = Path.GetDirectoryName(myFile);
                return myPath;
            }
        }

        /// <summary>
        /// The values to add to the registry.
        /// </summary>
        private static Variable[] TargetValues
        {
            get
            {
                Variable[] newval = {
                    new Variable("PATH",    InstallPath + Path.DirectorySeparatorChar + "bin", false, false),
                    new Variable("RAYPATH", InstallPath + Path.DirectorySeparatorChar + "lib", true,  true )
                };
                return newval;
            }
        }

        /// <summary>
        /// The maximum length of an environment variable string
        /// </summary>
        private static int MaxPathLength
        {
            get
            {
                return 2047;
            }
        }

        public override void Install(IDictionary stateSaver)
        {
            base.Install(stateSaver);

            foreach (Variable target in TargetValues)
            {
                bool allUsers = string.Compare(Context.Parameters["allusers"], "1", false) == 0;
                string prev = GetValue(target, allUsers);
                if (target.UserOverride && !allUsers && string.IsNullOrWhiteSpace(prev))
                {
                    // Copy the system values into the user value
                    prev = GetValue(target, true);
                }
                /* TODO if (target.UserOverride && allUsers && !string.IsNullOrWhiteSpace(GetValue(target, false)))
                 * then add the value to both the user and system variables
                 * but Windows doesn't make the user variable visible when allUsers is true */
                string newval = AddPath(prev, target.Value);
                bool changed = string.Compare(newval, prev, true) != 0 && newval.Length <= MaxPathLength;

                stateSaver.Add("previous_" + target.Name, prev);
                stateSaver.Add("allusers_" + target.Name, allUsers);
                stateSaver.Add("changed_" + target.Name, changed);

                if (changed) //out with the old
                    SetValue(target, newval, allUsers);
            }

            SetTDR();

            GrantAccess(InstallPath);

            BroadcastEnvironment();
            System.Diagnostics.Process.Start("http://mit.edu/sustainabledesignlab/projects/Accelerad/welcome.html");
            //System.Diagnostics.Process.Start(InstallPath + Path.DirectorySeparatorChar + "README.pdf");
        }

        public override void Uninstall(IDictionary savedState)
        {
            base.Uninstall(savedState);

            // Delete the test files if they were created
            DeleteFile(InstallPath + Path.DirectorySeparatorChar + "demo" + Path.DirectorySeparatorChar + "test_rpict.hdr");
            DeleteFile(InstallPath + Path.DirectorySeparatorChar + "demo" + Path.DirectorySeparatorChar + "test_rtrace.txt");
            DeleteFile(InstallPath + Path.DirectorySeparatorChar + "demo" + Path.DirectorySeparatorChar + "test_rcontrib.txt");

            foreach (Variable target in TargetValues)
            {
                if ((bool)savedState["changed_" + target.Name])
                {
                    bool allUsers = (bool)savedState["allusers_" + target.Name];
                    string newval = RemovePath(GetValue(target, allUsers), target.Value);
                    SetValue(target, newval, allUsers);
                }
            }

            BroadcastEnvironment();
        }

        public override void Rollback(IDictionary savedState)
        {
            base.Rollback(savedState);
            foreach (Variable target in TargetValues)
            {
                if ((bool)savedState["changed_" + target.Name])
                    SetValue(target, (string)savedState["previous_" + target.Name], (bool)savedState["allusers_" + target.Name]);
            }

            BroadcastEnvironment();
        }

        /// <summary>
        /// Delete a file.
        /// </summary>
        /// <param name="path">Path to file</param>
        /// <returns>Success</returns>
        private static bool DeleteFile(string path)
        {
            try
            {
                File.Delete(path);
            }
            catch (Exception)
            {
                return false;
            }
            return true;
        }

        private static RegistryKey GetEnvironmentKey(bool allUsers, bool writable)
        {
            if (allUsers)
            {
                // user selected "Everyone"
                // for the system-wide path...
                return Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Control\Session Manager\Environment", writable);
            }

            // user selected "Just Me"
            // for the user-specific path...
            return Registry.CurrentUser.OpenSubKey("Environment", writable);
        }

        private static void SetValue(Variable target, string value, bool allUsers)
        {
            using (RegistryKey reg = GetEnvironmentKey(allUsers, true))
            {
                if (string.IsNullOrWhiteSpace(value) && target.DeleteWhenEmpty)
                    reg.DeleteValue(target.Name);
                else
                    reg.SetValue(target.Name, value, value.Contains("%") ? RegistryValueKind.ExpandString : RegistryValueKind.String);
            }
        }

        private static string GetValue(Variable target, bool allUsers)
        {
            using (RegistryKey reg = GetEnvironmentKey(allUsers, false))
            {
                return (string)reg.GetValue(target.Name, string.Empty, RegistryValueOptions.DoNotExpandEnvironmentNames);
            }
        }

        private static string AddPath(string list, string item)
        {
            if (string.IsNullOrWhiteSpace(list))
                return item;

            List<string> paths = new List<string>(list.Split(';'));
            foreach (string path in paths)
                if (string.Compare(path.Trim(), item.Trim(), true) == 0) //trim to compare without leading or trailing whitespace
                {
                    // already present
                    return list;
                }

            try
            {
                paths.Insert(".".Equals(paths[0].Trim()) ? 1 : 0, item);
            }
            catch (System.ArgumentOutOfRangeException)
            {
                paths.Add(item);
            }
            return string.Join(";", paths.ToArray());
        }

        private static string RemovePath(string list, string item) //only removes one instance of item
        {
            List<string> paths = new List<string>(list.Split(';'));

            for (int i = 0; i < paths.Count; i++)
                if (string.Compare(paths[i].Trim(), item.Trim(), true) == 0)
                {
                    try
                    {
                        paths.RemoveAt(i);
                        return string.Join(";", paths.ToArray());
                    }
                    catch (Exception)
                    {
                        return list;
                    }
                }

            // not present
            return list;
        }

        /// <summary>
        /// Set the TDR timeout
        /// </summary>
        /// <returns>Success</returns>
        private bool SetTDR()
        {
            int option = 0;
            Int32.TryParse(Context.Parameters["tdr"], out option);
            if (option <= 1) return true;

            int delay = 2;
            int level = 3;
            switch (option)
            {
                case 2: // 10 second delay
                    delay = 10;
                    break;
                case 3: // 60 second delay
                    delay = 60;
                    break;
                case 4: // no timeout
                    level = 0;
                    break;
            }

            try
            {
                using (RegistryKey reg = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Control\GraphicsDrivers", true))
                {
                    reg.SetValue("TdrDelay", delay, RegistryValueKind.DWord);
                    reg.SetValue("TdrLevel", level, RegistryValueKind.DWord);
                }
            }
            catch (Exception)
            {
                return false;
            }
            return true;
        }

        /// <summary>
        /// From http://stackoverflow.com/questions/9108399/how-to-grant-full-permission-to-a-file-created-by-my-application-for-all-users
        /// </summary>
        /// <param name="path">Path to file or directory</param>
        /// <returns>Success</returns>
        private static bool GrantAccess(string path)
        {
            try
            {
                DirectoryInfo dInfo = new DirectoryInfo(path);
                DirectorySecurity dSecurity = dInfo.GetAccessControl();
                dSecurity.AddAccessRule(new FileSystemAccessRule(new SecurityIdentifier(WellKnownSidType.WorldSid, null), FileSystemRights.FullControl, InheritanceFlags.ObjectInherit | InheritanceFlags.ContainerInherit, PropagationFlags.None, AccessControlType.Allow));
                dInfo.SetAccessControl(dSecurity);
            }
            catch (Exception)
            {
                return false;
            }
            return true;
        }

        /// <summary>
        /// From https://devio.wordpress.com/2011/04/06/adding-application-directory-to-path-variable-in-visual-studio-setup-projects/
        /// </summary>
        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool SendMessageTimeout(
            IntPtr hWnd,
            int Msg,
            int wParam,
            string lParam,
            int fuFlags,
            int uTimeout,
            out int lpdwResult
        );

        private static void BroadcastEnvironment()
        {
            const int HWND_BROADCAST = 0xffff;
            const int WM_SETTINGCHANGE = 0x001A;
            const int SMTO_NORMAL = 0x0000;
            const int SMTO_BLOCK = 0x0001;
            const int SMTO_ABORTIFHUNG = 0x0002;
            const int SMTO_NOTIMEOUTIFNOTHUNG = 0x0008;

            int result;
            SendMessageTimeout((IntPtr)HWND_BROADCAST, WM_SETTINGCHANGE, 0, "Environment",
                SMTO_BLOCK | SMTO_ABORTIFHUNG | SMTO_NOTIMEOUTIFNOTHUNG, 5000, out result);
        }

    }

    /// <summary>
    /// Class representing an environment variable
    /// </summary>
    public class Variable
    {
        /// <summary>
        /// Constructor for an environment variable
        /// </summary>
        /// <param name="name">Name of environment variable</param>
        /// <param name="value">Value to be added to or removed from environment variable</param>
        /// <param name="userOverride">If true, the user variable will override the system variable. If false, they are concatinated.</param>
        /// <param name="deleteWhenEmpty">If true, the environment variable should be deleted if it becomes empty</param>
        public Variable(string name, string value, bool userOverride, bool deleteWhenEmpty)
        {
            Name = name.ToUpper();
            Value = value;
            UserOverride = userOverride;
            DeleteWhenEmpty = deleteWhenEmpty;
        }

        // Properties.
        public string Name { get; private set; }
        public string Value { get; private set; }
        public bool UserOverride { get; private set; }
        public bool DeleteWhenEmpty { get; private set; }

        public override string ToString()
        {
            return Name + ": " + Value;
        }
    }
}