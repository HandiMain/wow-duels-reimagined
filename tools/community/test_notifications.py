from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]/"addon"/"DuelsReimagined"
def read(p): return (ROOT/p).read_text(encoding="utf-8")
class NotificationTests(unittest.TestCase):
    def test_shared_card_and_effects_channel(self):
        u=read("UI/Notifications.lua")
        for token in ('pcall(PlaySoundFile,SOUND,"SFX")','ns.Motion','ns.Presence.Subscribe','ns.DuelDetection.Subscribe',
                      'GetNotificationAnchor','if #queue>=8','PREVIEW: Addon update','Settings.SnoozeUpdate',
                      'ns.Footer.ShowReleaseLink','NotificationArt.png'):
            self.assertIn(token,u)
        for token in ('SetCVar(','SendAddonMessage(','RecordLocalObservation(','OnUpdate','"Master"'):
            self.assertNotIn(token,u)
        self.assertTrue((ROOT/"Media/Sounds/Notifications/General.mp3").is_file())
        self.assertTrue((ROOT/"Media/Skin/NotificationArt.png").is_file())
    def test_release_evidence_and_development_gate(self):
        u=read("Core/UpdateNotices.lua")
        self.assertIn('if n>=2',u)
        self.assertIn('if not mine or not latest',u)
        self.assertIn('development build; preview only',u)
        self.assertNotIn('PatchNotesData',u)
        self.assertNotIn('Comm.Send',u)

    def test_visual_atlas_and_shared_button_sampling(self):
        import struct
        data=(ROOT/"Media/Skin/NotificationArt.png").read_bytes()
        self.assertEqual(struct.unpack(">II",data[16:24]),(1024,512))
        u=read("UI/Notifications.lua")
        self.assertIn('8,8,792,356',u)
        self.assertIn('8,372,792,66',u)
        self.assertIn('tx:SetTexture(HUD_ART)',u)
        self.assertIn('local ay=gold and 64 or 100',u)
        self.assertNotIn('218.25/256',u)
