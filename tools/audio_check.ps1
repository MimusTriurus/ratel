# What Windows does with the sound, for when the preview is silent and
# Level3DAudio's --audio-debug says the buses are not: the default output
# device, its master volume and mute, and every app's session in the volume
# mixer -- Godot's among them once it has played something -- with its own
# volume and mute.
#
#     powershell -ExecutionPolicy Bypass -File tools/audio_check.ps1
#
# Read-only: it changes no volume and unmutes nothing. Windows' Core Audio
# through COM, as the volume mixer itself reads it.

$source = @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
    int NotImpl1();
    [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device);
}
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
    [PreserveSig] int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object iface);
    [PreserveSig] int OpenPropertyStore(int access, out IPropertyStore store);
}
[Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IPropertyStore {
    int GetCount(out int count);
    int GetAt(int index, out PropertyKey key);
    [PreserveSig] int GetValue(ref PropertyKey key, out PropVariant value);
}
[StructLayout(LayoutKind.Sequential)]
struct PropertyKey { public Guid fmtid; public int pid; }
[StructLayout(LayoutKind.Explicit)]
struct PropVariant { [FieldOffset(0)] public short vt; [FieldOffset(8)] public IntPtr pointer; [FieldOffset(16)] public long pad; }
[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioEndpointVolume {
    int RegisterControlChangeNotify(IntPtr notify);
    int UnregisterControlChangeNotify(IntPtr notify);
    int GetChannelCount(out int count);
    int SetMasterVolumeLevel(float level, ref Guid context);
    int SetMasterVolumeLevelScalar(float level, ref Guid context);
    int GetMasterVolumeLevel(out float level);
    int GetMasterVolumeLevelScalar(out float level);
    int SetChannelVolumeLevel(int channel, float level, ref Guid context);
    int SetChannelVolumeLevelScalar(int channel, float level, ref Guid context);
    int GetChannelVolumeLevel(int channel, out float level);
    int GetChannelVolumeLevelScalar(int channel, out float level);
    int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, ref Guid context);
    int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
}
[Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionManager2 {
    int GetAudioSessionControl(IntPtr a, int b, out IntPtr c);
    int GetSimpleAudioVolume(IntPtr a, int b, out IntPtr c);
    [PreserveSig] int GetSessionEnumerator(out IAudioSessionEnumerator sessions);
}
[Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionEnumerator {
    int GetCount(out int count);
    int GetSession(int index, out IAudioSessionControl2 session);
}
[Guid("bfb7ff88-7239-4fc9-8fa2-07c950be9c6d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionControl2 {
    int GetState(out int state);
    int GetDisplayName([MarshalAs(UnmanagedType.LPWStr)] out string name);
    int SetDisplayName(string a, ref Guid b);
    int GetIconPath(out IntPtr a);
    int SetIconPath(string a, ref Guid b);
    int GetGroupingParam(out Guid a);
    int SetGroupingParam(ref Guid a, ref Guid b);
    int RegisterAudioSessionNotification(IntPtr a);
    int UnregisterAudioSessionNotification(IntPtr a);
    int GetSessionIdentifier(out IntPtr a);
    int GetSessionInstanceIdentifier(out IntPtr a);
    int GetProcessId(out uint pid);
}
[Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface ISimpleAudioVolume {
    int SetMasterVolume(float level, ref Guid context);
    int GetMasterVolume(out float level);
    int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, ref Guid context);
    int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
}
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
class MMDeviceEnumeratorCom {}

public class Session { public uint Pid; public string State; public float Volume; public bool Muted; }

public static class CoreAudio {
    const int CLSCTX_ALL = 23;
    static IMMDevice Device() {
        var e = (IMMDeviceEnumerator)new MMDeviceEnumeratorCom();
        IMMDevice d;
        Marshal.ThrowExceptionForHR(e.GetDefaultAudioEndpoint(0, 1, out d));  // render, multimedia
        return d;
    }
    public static string DeviceName() {
        IPropertyStore store;
        Device().OpenPropertyStore(0, out store);
        var key = new PropertyKey { fmtid = new Guid("a45c254e-df1c-4efd-8020-67d146a850e0"), pid = 14 };
        PropVariant v;
        store.GetValue(ref key, out v);
        return v.vt == 31 ? Marshal.PtrToStringUni(v.pointer) : "?";
    }
    public static float MasterVolume(out bool muted) {
        var iid = typeof(IAudioEndpointVolume).GUID;
        object o;
        Marshal.ThrowExceptionForHR(Device().Activate(ref iid, CLSCTX_ALL, IntPtr.Zero, out o));
        var v = (IAudioEndpointVolume)o;
        float level;
        v.GetMasterVolumeLevelScalar(out level);
        v.GetMute(out muted);
        return level;
    }
    public static List<Session> Sessions() {
        var iid = typeof(IAudioSessionManager2).GUID;
        object o;
        Marshal.ThrowExceptionForHR(Device().Activate(ref iid, CLSCTX_ALL, IntPtr.Zero, out o));
        IAudioSessionEnumerator e;
        ((IAudioSessionManager2)o).GetSessionEnumerator(out e);
        int n;
        e.GetCount(out n);
        var list = new List<Session>();
        for (int i = 0; i < n; i++) {
            IAudioSessionControl2 s;
            e.GetSession(i, out s);
            var r = new Session();
            s.GetProcessId(out r.Pid);
            int state;
            s.GetState(out state);
            r.State = state == 1 ? "active" : state == 0 ? "inactive" : "expired";
            var simple = (ISimpleAudioVolume)s;
            simple.GetMasterVolume(out r.Volume);
            simple.GetMute(out r.Muted);
            list.Add(r);
        }
        return list;
    }
}
"@
Add-Type -TypeDefinition $source

$muted = $false
$level = [CoreAudio]::MasterVolume([ref]$muted)
"Output device: " + [CoreAudio]::DeviceName()
"Master volume: {0:P0}{1}" -f $level, $(if ($muted) { "  MUTED" } else { "" })
""
"Apps in the volume mixer:"
foreach ($s in [CoreAudio]::Sessions()) {
    $name = if ($s.Pid -eq 0) { "System sounds" } else {
        $p = Get-Process -Id $s.Pid -ErrorAction SilentlyContinue
        if ($p) { $p.ProcessName } else { "pid $($s.Pid)" }
    }
    $flag = if ($s.Muted) { "  MUTED" } elseif ($s.Volume -lt 0.05) { "  (almost silent)" } else { "" }
    "  {0,-40} {1,-9} {2,5:P0}{3}" -f $name, $s.State, $s.Volume, $flag
}
$godot = [CoreAudio]::Sessions() | Where-Object {
    $p = Get-Process -Id $_.Pid -ErrorAction SilentlyContinue; $p -and $p.ProcessName -like "Godot*" }
""
if (-not $godot) {
    "No Godot in the mixer: it is not running, or has not played anything on this device yet."
} elseif ($godot | Where-Object { $_.Muted -or $_.Volume -lt 0.05 }) {
    "Godot is muted or turned down in the volume mixer."
} elseif ($muted -or $level -lt 0.05) {
    "The device itself is muted or turned down."
} else {
    "Windows passes Godot's sound through to '" + [CoreAudio]::DeviceName() + "'."
}
