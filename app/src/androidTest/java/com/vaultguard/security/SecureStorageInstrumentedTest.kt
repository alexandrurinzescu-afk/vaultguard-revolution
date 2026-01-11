package com.vaultguard.security

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.vaultguard.security.models.DocumentMetadata
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.nio.charset.StandardCharsets

@RunWith(AndroidJUnit4::class)
class SecureStorageInstrumentedTest {

    @Test
    fun saveLoadListDelete_roundTrip() {
        val ctx = ApplicationProvider.getApplicationContext<android.content.Context>()
        val storage = SecureStorage(
            context = ctx,
            requireUserAuth = false, // non-interactive for tests
        )

        val name = "ticket_001"
        storage.deleteStoredDocument(name)

        val data = "vaultguard-secure-storage".toByteArray(StandardCharsets.UTF_8)
        assertTrue(storage.saveEncryptedDocument(data, name))

        val listed = storage.listStoredDocuments()
        assertTrue(listed.contains(name))

        val loaded = storage.loadEncryptedDocument(name)
        assertArrayEquals(data, loaded)

        assertTrue(storage.deleteStoredDocument(name))
    }

    @Test
    fun exportRestoreEncryptedBackup_restoresBlobs() {
        val ctx = ApplicationProvider.getApplicationContext<android.content.Context>()
        val storage = SecureStorage(
            context = ctx,
            requireUserAuth = false,
        )

        val n1 = "docA"
        val n2 = "docB"
        storage.deleteStoredDocument(n1)
        storage.deleteStoredDocument(n2)

        assertTrue(storage.saveEncryptedDocument("A".toByteArray(), n1))
        assertTrue(storage.saveEncryptedDocument("B".toByteArray(), n2))

        // Attach metadata to one doc to ensure backup/restore includes .vgmeta.
        assertTrue(
            storage.saveDocumentWithMetadata(
                data = "A".toByteArray(),
                fileName = n1,
                metadata = DocumentMetadata(type = "TICKET", issuingAuthority = "STADIUM"),
            )
        )

        val zip = storage.exportEncryptedBackup()
        assertTrue(zip.exists())

        // delete originals
        storage.deleteStoredDocument(n1)
        storage.deleteStoredDocument(n2)
        assertEquals(null, storage.loadEncryptedDocument(n1))

        val restored = storage.restoreEncryptedBackup(zip, overwrite = true)
        assertTrue(restored >= 2) // .vgenc + .vgmeta may increase count

        assertArrayEquals("A".toByteArray(), storage.loadEncryptedDocument(n1))
        assertArrayEquals("B".toByteArray(), storage.loadEncryptedDocument(n2))
        val meta = storage.getDocumentMetadata(n1)
        assertEquals("TICKET", meta?.type)
    }

    @Test
    fun saveGetSearchByType_works() {
        val ctx = ApplicationProvider.getApplicationContext<android.content.Context>()
        val storage = SecureStorage(context = ctx, requireUserAuth = false)

        val n1 = "ticket_meta_1"
        val n2 = "doc_meta_2"
        storage.deleteStoredDocument(n1)
        storage.deleteStoredDocument(n2)

        assertTrue(storage.saveDocumentWithMetadata("X".toByteArray(), n1, DocumentMetadata(type = "TICKET")))
        assertTrue(storage.saveDocumentWithMetadata("Y".toByteArray(), n2, DocumentMetadata(type = "DOCUMENT")))

        assertEquals("TICKET", storage.getDocumentMetadata(n1)?.type)
        val tickets = storage.searchByType("TICKET")
        assertTrue(tickets.contains(n1))
        assertTrue(!tickets.contains(n2))

        storage.deleteStoredDocument(n1)
        storage.deleteStoredDocument(n2)
    }
}

