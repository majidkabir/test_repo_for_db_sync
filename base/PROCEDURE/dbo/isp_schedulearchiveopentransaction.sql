SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Proc : isp_ScheduleArchiveOpenTransaction                      */  
/* Creation Date: 2007/06/18                                             */  
/* Copyright: IDS                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose:                                                              */  
/*                                                                       */  
/* Called By: Job Name Archive Open Transaction > 90/365 days            */  
/*                                                                       */  
/* PVCS Version: 1.9                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author        Purposes                                   */  
/* 16 Oct 15    tlting revise transferdetail column                      */  
/* 17 Jan 15    khlim  rename idssg_archive to SGARCHIVE                 */  
/* 17 Mar 19    TLTING Transferdetail column add                         */  
/* 23-Jul-2020  Shong  Remove Hardcoded script and using ArchiveParameter*/ 
/************************************************************************/          
CREATE PROCEDURE [dbo].[isp_ScheduleArchiveOpenTransaction] 
   @c_Archivekey NVARCHAR(10) = '',
   @b_Success    INT = 1 OUTPUT,
   @n_Err        INT = 0 OUTPUT,
   @c_Errmsg     NVARCHAR(250) = '' OUTPUT,
   @b_Debug      INT = 0
AS        
BEGIN
   SET NOCOUNT ON 
   
   DECLARE @cPOKey NVARCHAR(10)        
         , @nRowCount INT        
         , @n_AdjNumberofDaysToRetain  INT = 0
         , @n_AlertNumberofDaysToRetain  INT = 0
         , @n_CaseMNumberofDaysToRetain  INT = 0
         , @n_CCNumberofDaysToRetain  INT = 0
         , @n_ContainerNumberofDaysToRetain  INT = 0
         , @n_DailyInvNoofDaysToRetain  INT = 0
         , @n_DelPickslipNoofDaysToRetain  INT = 0
         , @n_ErrLogNumberofDaysToRetain  INT = 0
         , @n_GUINumberofDaysToRetain  INT = 0
         , @n_HAWBNumberofDaysToRetain  INT = 0
         , @n_InvHoldNumberofDaysToRetain  INT = 0
         , @n_InvQCNumberofDaysToRetain  INT = 0
         , @n_InvrptLogNumberofDaysToRetain  INT = 0
         , @n_ItrnNumberofDaysToRetain  INT = 0
         , @n_KITNumberofDaysToRetain  INT = 0
         , @n_MAWBNumberofDaysToRetain  INT = 0
         , @n_MbolNumberofDaysToRetain  INT = 0
         , @n_OrdersLogNumberofDaysToRetain  INT = 0
         , @n_PackLogNumberofDaysToRetain  INT = 0
         , @n_PalletNumberofDaysToRetain  INT = 0
         , @n_PLSNumberofDaysToRetain  INT = 0
         , @n_PONumberofDaysToRetain  INT = 0
         , @n_PTraceNumberofDaysToRetain  INT = 0
         , @n_RdsOrdersNumberofDaysToRetain  INT = 0
         , @n_RdsPoNumberofDaysToRetain  INT = 0
         , @n_RDT_PPP_PPA_NoDaysToRetain  INT = 0
         , @n_RDT_TABLE_NoDaysToRetain  INT = 0
         , @n_RDTPPANoDaysToRetain  INT = 0
         , @n_ReceiptNumberofDaysToRetain  INT = 0
         , @n_REPLENISHNumberofDaysToRetain  INT = 0
         , @n_RFDBLogNumberofDaysToRetain  INT = 0
         , @n_ShipNumberofDaysToRetain  INT = 0
         , @n_SKULogNumberofDaysToRetain  INT = 0
         , @n_SMSPODNumberofDaysToRetain  INT = 0
         , @n_TranmLogNumberofDaysToRetain  INT = 0
         , @n_TranNumberofDaysToRetain  INT = 0
         , @n_TrigLogNumberofDaysToRetain  INT = 0
         , @c_ArchiveDatabaseName NVARCHAR(100)
         , @c_SQLStatement     NVARCHAR(4000)

   IF @c_Archivekey <> ''
   BEGIN
      SELECT  @c_ArchiveDatabaseName           = ArchiveDatabaseName
            , @n_AdjNumberofDaysToRetain       = AdjNumberofDaysToRetain
            , @n_AlertNumberofDaysToRetain     = AlertNumberofDaysToRetain
            , @n_CaseMNumberofDaysToRetain     = CaseMNumberofDaysToRetain
            , @n_CCNumberofDaysToRetain        = CCNumberofDaysToRetain
            , @n_ContainerNumberofDaysToRetain = ContainerNumberofDaysToRetain
            , @n_DailyInvNoofDaysToRetain      = DailyInvNoofDaysToRetain
            , @n_DelPickslipNoofDaysToRetain   = DelPickslipNoofDaysToRetain
            , @n_ErrLogNumberofDaysToRetain    = ErrLogNumberofDaysToRetain
            , @n_GUINumberofDaysToRetain       = GUINumberofDaysToRetain
            , @n_HAWBNumberofDaysToRetain      = HAWBNumberofDaysToRetain
            , @n_InvHoldNumberofDaysToRetain   = InvHoldNumberofDaysToRetain
            , @n_InvQCNumberofDaysToRetain     = InvQCNumberofDaysToRetain
            , @n_InvrptLogNumberofDaysToRetain = InvrptLogNumberofDaysToRetain
            , @n_ItrnNumberofDaysToRetain      = ItrnNumberofDaysToRetain
            , @n_KITNumberofDaysToRetain       = KITNumberofDaysToRetain
            , @n_MAWBNumberofDaysToRetain      = MAWBNumberofDaysToRetain
            , @n_MbolNumberofDaysToRetain      = MbolNumberofDaysToRetain
            , @n_OrdersLogNumberofDaysToRetain = OrdersLogNumberofDaysToRetain
            , @n_PackLogNumberofDaysToRetain   = PackLogNumberofDaysToRetain
            , @n_PalletNumberofDaysToRetain    = PalletNumberofDaysToRetain
            , @n_PLSNumberofDaysToRetain       = PLSNumberofDaysToRetain
            , @n_PONumberofDaysToRetain        = PONumberofDaysToRetain
            , @n_PTraceNumberofDaysToRetain    = PTraceNumberofDaysToRetain
            , @n_RdsOrdersNumberofDaysToRetain = RdsOrdersNumberofDaysToRetain
            , @n_RdsPoNumberofDaysToRetain     = RdsPoNumberofDaysToRetain
            , @n_ReceiptNumberofDaysToRetain   = ReceiptNumberofDaysToRetain
            , @n_REPLENISHNumberofDaysToRetain = REPLENISHNumberofDaysToRetain
            , @n_RFDBLogNumberofDaysToRetain   = RFDBLogNumberofDaysToRetain
            , @n_ShipNumberofDaysToRetain      = ShipNumberofDaysToRetain
            , @n_SKULogNumberofDaysToRetain    = SKULogNumberofDaysToRetain
            , @n_SMSPODNumberofDaysToRetain    = SMSPODNumberofDaysToRetain
            , @n_TranmLogNumberofDaysToRetain  = TranmLogNumberofDaysToRetain
            , @n_TranNumberofDaysToRetain      = TranNumberofDaysToRetain
            , @n_TrigLogNumberofDaysToRetain   = TrigLogNumberofDaysToRetain  
      FROM   ArchiveParameters (NOLOCK)
      WHERE  archivekey = @c_archivekey        
   END -- @c_archivekey <> ''
   ELSE 
   BEGIN
      SELECT @c_ArchiveDatabaseName = LEFT(DB_NAME(), 2) + 'ARCHIVE'
      IF NOT EXISTS (SELECT name FROM master.dbo.sysdatabases 
                     WHERE ('[' + name + ']' = @c_ArchiveDatabaseName OR name = @c_ArchiveDatabaseName))
      BEGIN
         PRINT 'DB NAME ' + @c_ArchiveDatabaseName + ' Not EXISTS'
         GOTO EXIT_SP
      END
      ELSE 
         PRINT 'DB NAME ' + @c_ArchiveDatabaseName + ' EXISTS'
   END
   
   
   IF @n_PONumberofDaysToRetain = 0 
      SET @n_PONumberofDaysToRetain = 365
   
   SET @nRowCount = 0 
             
   DECLARE CUR_POKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT p.POkey         
    FROM PO p WITH (NOLOCK)        
     LEFT JOIN RECEIPT r (NOLOCK) ON (p.POkey = r.POkey)        
     LEFT JOIN RECEIPTDETAIL rd (NOLOCK) ON (p.POkey = rd.POkey)        
    WHERE r.POkey IS NULL        
      AND   rd.POkey IS NULL        
      AND   DATEDIFF(DAY,CASE         
     WHEN p.EditDate>p.EffectiveDate THEN p.EditDate         
    ELSE p.EffectiveDate END,GETDATE())> @n_PONumberofDaysToRetain
   ORDER BY p.POKey        

   OPEN CUR_POKEY

   FETCH FROM CUR_POKEY INTO @cPOKey

   WHILE @@FETCH_STATUS = 0
   BEGIN
      UPDATE PO SET archivecop = '9', Trafficcop = null        
           WHERE POkey = @cPOkey        
        
         UPDATE PODetail SET archivecop = '9', Trafficcop = null        
           WHERE POkey = @cPOkey        
        
         SELECT @nRowCount = @nRowCount + 1       

      FETCH FROM CUR_POKEY INTO @cPOKey
   END

   CLOSE CUR_POKEY
   DEALLOCATE CUR_POKEY

   PRINT '*** ' + CONVERT(NVARCHAR(12), @nRowCount) + ' open PO archived ***'        
                
   ---START Archive Open ASN        
   DECLARE @cReceiptKey NVARCHAR(10)         

   /* SG-PW Changed to Adddate from EditDate */        

   IF @n_ReceiptNumberofDaysToRetain = 0 
      SET @n_ReceiptNumberofDaysToRetain = 90
   
   SET @nRowCount = 0
   
   DECLARE CUR_RECEIPTKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT r.Receiptkey         
     FROM RECEIPT r (NOLOCK)        
   WHERE DATEDIFF(DAY,CASE         
   WHEN r.EditDate>r.EffectiveDate THEN r.AddDate         
    ELSE r.EffectiveDate END,GETDATE())> @n_ReceiptNumberofDaysToRetain  
   ORDER BY r.ReceiptKey      
   
   OPEN CUR_RECEIPTKEY
   
   FETCH FROM CUR_RECEIPTKEY INTO @cReceiptkey
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
      UPDATE Receipt WITH (ROWLOCK)  
      SET archivecop = '9', Trafficcop = null        
        WHERE Receiptkey = @cReceiptkey        
        
      UPDATE ReceiptDetail 
         SET archivecop = '9', Trafficcop = null        
        WHERE Receiptkey = @cReceiptkey        
        
      SELECT @nRowCount = @nRowCount + 1 
   
      FETCH FROM CUR_RECEIPTKEY INTO @cReceiptkey
   END
   
   CLOSE CUR_RECEIPTKEY
   DEALLOCATE CUR_RECEIPTKEY
        
   PRINT '*** ' + CONVERT(NVARCHAR(12), @nRowCount) + ' open ASN archived ***'        
        
   ---START Archive Open Transfer        
   DECLARE @cTransferKey NVARCHAR(10)        
        
   /* SG-PW Changed to Adddate from EditDate */           
   IF @n_TranNumberofDaysToRetain = 0 
      SET @n_TranNumberofDaysToRetain=90      
   
   SET @nRowCount = 0
   
   DECLARE CUR_TransferKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT t.TransferKey         
     FROM Transfer t (NOLOCK)        
    WHERE DATEDIFF(DAY,t.AddDate,GETDATE())> @n_TranNumberofDaysToRetain     
   ORDER BY t.TransferKey  
   
   OPEN CUR_TransferKey
   
   FETCH FROM CUR_TransferKey INTO @cTransferKey
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
      UPDATE Transfer SET archivecop = '9', Trafficcop = null        
        WHERE TransferKey = @cTransferKey        
        
      UPDATE TransferDetail SET archivecop = '9', Trafficcop = null        
        WHERE TransferKey = @cTransferKey        
        
      SELECT @nRowCount = @nRowCount + 1      
   
      FETCH FROM CUR_TransferKey INTO @cTransferKey
   END
   
   CLOSE CUR_TransferKey
   DEALLOCATE CUR_TransferKey
   
   /* SG-PW Archive */       
   
   SET @c_SQLStatement = N'INSERT INTO ' + RTRIM(@c_ArchiveDatabaseName) + N'.dbo.[Transfer]  (
      TransferKey, FromStorerKey, ToStorerKey, TYPE, OpenQty, STATUS, GenerateHOCharges, GenerateIS_HICharges, ReLot, 
          EffectiveDate, AddDate, AddWho, EditDate, EditWho, TrafficCop, ArchiveCop, ReasonCode, CustomerRefNo, Remarks, 
          Facility, PrintFlag, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, UserDefine06, 
          UserDefine07, UserDefine08, UserDefine09, UserDefine10, ToFacility ) 
   SELECT TransferKey, FromStorerKey, ToStorerKey, TYPE, OpenQty, STATUS, GenerateHOCharges, GenerateIS_HICharges, ReLot, 
          EffectiveDate, AddDate, AddWho, EditDate, EditWho, TrafficCop, ArchiveCop, ReasonCode, CustomerRefNo, Remarks, 
          Facility, PrintFlag, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, UserDefine06, 
          UserDefine07, UserDefine08, UserDefine09, UserDefine10, ToFacility
   FROM   TRANSFER WITH (NOLOCK)
   WHERE  archivecop = ''9'' '
    
   EXEC (@c_SQLStatement)  
      
   /* SG-PW Delete */        
   DELETE FROM Transfer         
   WHERE archivecop = '9'
           
   /*SG-PW Archive */   
   SET @c_SQLStatement = N'INSERT INTO ' + RTRIM(@c_ArchiveDatabaseName) + N'.dbo.TransferDetail 
   (TransferKey, TransferLineNumber, FromStorerKey, FromSku, FromLoc, FromLot, FromId, FromQty, FromPackKey, 
          FromUOM, LOTTABLE01, LOTTABLE02, LOTTABLE03, LOTTABLE04, LOTTABLE05, ToStorerKey, ToSku, ToLoc, ToLot, ToId, 
          ToQty, ToPackKey, ToUOM, STATUS, EffectiveDate, AddDate, AddWho, EditDate, EditWho, TrafficCop, ArchiveCop, 
          tolottable01, tolottable02, tolottable03, tolottable04, tolottable05, UserDefine01, UserDefine02, UserDefine03, 
          UserDefine04, UserDefine05, UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10, Lottable06, 
          Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, 
          ToLottable06, ToLottable07, ToLottable08, ToLottable09, ToLottable10, ToLottable11, ToLottable12, ToLottable13, 
          ToLottable14, ToLottable15, FromChannel, ToChannel, FromChannel_ID, ToChannel_ID)   
   SELECT TransferKey, TransferLineNumber, FromStorerKey, FromSku, FromLoc, FromLot, FromId, FromQty, FromPackKey, 
          FromUOM, LOTTABLE01, LOTTABLE02, LOTTABLE03, LOTTABLE04, LOTTABLE05, ToStorerKey, ToSku, ToLoc, ToLot, ToId, 
          ToQty, ToPackKey, ToUOM, STATUS, EffectiveDate, AddDate, AddWho, EditDate, EditWho, TrafficCop, ArchiveCop, 
          tolottable01, tolottable02, tolottable03, tolottable04, tolottable05, UserDefine01, UserDefine02, UserDefine03, 
          UserDefine04, UserDefine05, UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10, Lottable06, 
          Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, 
          ToLottable06, ToLottable07, ToLottable08, ToLottable09, ToLottable10, ToLottable11, ToLottable12, ToLottable13, 
          ToLottable14, ToLottable15, FromChannel, ToChannel, FromChannel_ID, ToChannel_ID
   FROM TransferDetail WITH (NOLOCK) 
   WHERE  archivecop = ''9'' '
        
   EXEC (@c_SQLStatement)
   
   /* SG-PW Delete */        
   DELETE FROM TransferDetail        
   WHERE archivecop = '9'        
        
   PRINT '*** ' + CONVERT(NVARCHAR(12), @nRowCount) + ' open Transfer archived ***'        

   ---SG - Archive Open PO Adddate 180 days        
   /*        
   Version Description    Date   By        
   1.0.0 Archive Open PO based on Adddate  20070502 SG-PW        
    Also no receipt records with same POKey        
   */        
   SET @nRowCount = 0
   
   DECLARE CUR_POKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT p.POkey        
   FROM PO p(NOLOCK)        
   WHERE DATEDIFF(DAY,CASE         
     WHEN p.Adddate>p.EffectiveDate THEN p.Adddate         
     ELSE p.EffectiveDate END,GETDATE()) > @n_PONumberofDaysToRetain        
   AND NOT EXISTS (SELECT 1 FROM RECEIPT WHERE POKey = p.POKey)         
   ORDER BY p.POKey

   OPEN CUR_POKEY

   FETCH FROM CUR_POKEY INTO @cPOKey

   WHILE @@FETCH_STATUS = 0
   BEGIN
      UPDATE PO SET archivecop = '9', Trafficcop = null        
           WHERE POkey = @cPOkey        
        
         UPDATE PODetail SET archivecop = '9', Trafficcop = null        
           WHERE POkey = @cPOkey        
        
         SELECT @nRowCount = @nRowCount + 1       

      FETCH FROM CUR_POKEY INTO @cPOKey
   END

   CLOSE CUR_POKEY
   DEALLOCATE CUR_POKEY
        
   PRINT '*** ' + CONVERT(NVARCHAR(12), @nRowCount) + ' open PO archived ***'        
        
   ---SG - Close SZ Orders (2 days)        
   /*        
   Version Description    Date   By        
   1.0.0 Healthcare SOs for Invoice only.   20070502 SG-PW        
    E1 autoclose after 2 days.         
    Set to autoclose in WMS after 2 days        
   */        

   DECLARE @cOrderKey nvarchar(10)
   SET @nRowCount = 0
   
   DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OrderKey 
   FROM ORDERS AS o WITH(NOLOCK)
   WHERE o.SOSTATUS = '0'        
   AND o.[Status] = '0'        
   AND o.externorderkey LIKE '36%'        
   AND o.externorderkey LIKE '%SZ%'        
   AND NOT EXISTS (SELECT 1 FROM ORDERDETAIL OD WITH (NOLOCK) WHERE OD.OrderKey = o.OrderKey )   
   AND Adddate <  DATEADD(DAY, -2, GETDATE()) 
   ORDER BY OrderKey     
   
   OPEN CUR_ORDERKEY
   
   FETCH FROM CUR_ORDERKEY INTO @cOrderKey
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
      UPDATE Orders WITH (ROWLOCK)         
         SET Trafficcop=NULL, Status = '9', SOSTATUS = '9'  
      WHERE OrderKey=@cOrderKey
      
      SELECT @nRowCount = @nRowCount + 1 
      
      FETCH FROM CUR_ORDERKEY INTO @cOrderKey
   END
   
   CLOSE CUR_ORDERKEY
   DEALLOCATE CUR_ORDERKEY
                
        
   PRINT '*** ' + CONVERT(NVARCHAR(12), @nRowCount) + 'SZ Orders closed ***'        
        
   ---SG - Purge LoadPlan Missing Detail        
   /* START SG-PW Added to pick out detail with no headers */        
   /* Use EditDate to prevent over archive */    
   DECLARE @cMBOLKey nvarchar(10), @cMBOLLineNumber nvarchar(5)
   
   SET @nRowCount = 0
      
   DECLARE CUR_POD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Mbolkey, Mbollinenumber
   FROM POD WITH (NOLOCK) 
   WHERE EditDate <  DATEADD(DAY, -90, GETDATE())
   ORDER BY Mbolkey, Mbollinenumber
   
          
   OPEN CUR_POD
   
   FETCH FROM CUR_POD INTO @cMBOLKey, @cMBOLLineNumber
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
      UPDATE POD         
      SET archivecop = '9', Trafficcop = NULL
      WHERE Mbolkey = @cMBOLKey
      AND Mbollinenumber = @cMBOLLineNumber
   
      SELECT @nRowCount = @nRowCount + 1
       
      FETCH FROM CUR_POD INTO @cMBOLKey, @cMBOLLineNumber
   END
   
   CLOSE CUR_POD
   DEALLOCATE CUR_POD


   PRINT '*** ' + CONVERT(NVARCHAR(12), @nRowCount) + ' POD Archived ***' 
    
   /* FINISH Added */        
        
   /*Perform the Archive */   
   SET @c_SQLStatement = N'INSERT INTO ' + RTRIM(@c_ArchiveDatabaseName)  + '.dbo.POD 
     (
       Mbolkey, Mbollinenumber, LoadKey, OrderKey, BuyerPO, ExternOrderKey, InvoiceNo, [Status], ActualDeliveryDate, 
       InvDespatchDate, PodReceivedDate, PodFiledDate, InvCancelDate, RedeliveryDate, RedeliveryCount, FullRejectDate, 
       ReturnRefNo, PartialRejectDate, RejectReasonCode, PoisonFormDate, PoisonFormNo, ChequeNo, ChequeAmount, 
       ChequeDate, Notes, Notes2, PODDef01, PODDef02, PODDef03, PODDef04, PODDef05, PODDef06, PODDef07, PODDef08, 
       PODDef09, PODDate01, PODDate02, PODDate03, PODDate04, PODDate05, TrackCol01, TrackCol02, TrackCol03, TrackCol04, 
       TrackCol05, TrackDate01, TrackDate02, TrackDate03, TrackDate04, TrackDate05, AddWho, AddDate, EditWho, EditDate, 
       TrafficCop, ArchiveCop, FinalizeFlag, Storerkey, SpecialHandling, Latitude, Longtitude, ExternLoadKey, RefDocID
     ) 
    SELECT Mbolkey, Mbollinenumber, LoadKey, OrderKey, BuyerPO, ExternOrderKey, InvoiceNo, [Status], ActualDeliveryDate, 
       InvDespatchDate, PodReceivedDate, PodFiledDate, InvCancelDate, RedeliveryDate, RedeliveryCount, FullRejectDate, 
       ReturnRefNo, PartialRejectDate, RejectReasonCode, PoisonFormDate, PoisonFormNo, ChequeNo, ChequeAmount, 
       ChequeDate, Notes, Notes2, PODDef01, PODDef02, PODDef03, PODDef04, PODDef05, PODDef06, PODDef07, PODDef08, 
       PODDef09, PODDate01, PODDate02, PODDate03, PODDate04, PODDate05, TrackCol01, TrackCol02, TrackCol03, TrackCol04, 
       TrackCol05, TrackDate01, TrackDate02, TrackDate03, TrackDate04, TrackDate05, AddWho, AddDate, EditWho, EditDate, 
       TrafficCop, ArchiveCop, FinalizeFlag, Storerkey, SpecialHandling, Latitude, Longtitude, ExternLoadKey, RefDocID       
   FROM POD WITH (NOLOCK)
   WHERE Archivecop = ''9'' '
        
   EXEC (@c_SQLStatement)        
        
   /*Delete from Production */        
   DELETE FROM POD        
   WHERE Archivecop = '9'        
        
   ---SG - Purge TramismitLog        
   /* Use EditDate to prevent over archive */        
   DECLARE @c_TransmitLogKey   NVARCHAR(10),
           @c_TableName        NVARCHAR(50)
   
   IF @n_TranmLogNumberofDaysToRetain = 0 
      SET @n_TranmLogNumberofDaysToRetain = 90
   
   SET @n_TranmLogNumberofDaysToRetain = ABS(@n_TranmLogNumberofDaysToRetain) * -1
   SET @nRowCount = 0
      
   DECLARE CUR_TRANSMITLOG CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT 'TRANSMITLOG', TransmitLogKey
   FROM TRANSMITLOG (NOLOCK)
   WHERE EditDate < DATEADD(DAY, @n_TranmLogNumberofDaysToRetain, GETDATE())
   UNION ALL 
   SELECT 'TRANSMITLOG2', TransmitLogKey
   FROM TRANSMITLOG2 (NOLOCK)
   WHERE EditDate < DATEADD(DAY, @n_TranmLogNumberofDaysToRetain, GETDATE())
   UNION ALL 
   SELECT 'TRANSMITLOG3', TransmitLogKey
   FROM TRANSMITLOG3 (NOLOCK)
   WHERE EditDate < DATEADD(DAY, @n_TranmLogNumberofDaysToRetain, GETDATE())
   ORDER BY TransmitLogKey
   
   OPEN CUR_TRANSMITLOG
   
   FETCH FROM CUR_TRANSMITLOG INTO @c_TableName, @c_TransmitLogKey
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @b_Debug = 1
      BEGIN
         PRINT '>> ' + @c_TableName + ' - ' + @c_TransmitLogKey
      END
      
      SET @c_SQLStatement = N' UPDATE ' + RTRIM(@c_TableName) + ' WITH (ROWLOCK) ' 
          + ' SET ArchiveCop = ''9'', Trafficcop = null ' 
          + ' WHERE TransmitLogKey = @c_TransmitLogKey '
      
      EXEC sp_ExecuteSQL @c_SQLStatement, N'@c_TransmitLogKey   NVARCHAR(10)', @c_TransmitLogKey 
      
      SET @c_SQLStatement = N'INSERT INTO ' + RTRIM(@c_ArchiveDatabaseName)  + '.dbo.' + @c_TableName +
      '  ( TransmitLogKey, TableName, key1, key2, key3, transmitflag, transmitbatch, AddDate, AddWho, EditDate, EditWho, ' +
      '    TrafficCop, ArchiveCop ) ' +
      ' SELECT TransmitLogKey, TableName, key1, key2, key3, transmitflag, transmitbatch, AddDate, AddWho, EditDate, EditWho, ' +
      '     TrafficCop, ArchiveCop ' +
      ' FROM ' + RTRIM(@c_TableName) + ' AS t WITH(NOLOCK) ' +
      ' WHERE TransmitLogKey = @c_TransmitLogKey ' +
      ' AND t.ArchiveCop = ''9'' '
      
      EXEC sp_ExecuteSQL @c_SQLStatement, N'@c_TransmitLogKey   NVARCHAR(10)', @c_TransmitLogKey
      
      SET @c_SQLStatement = N'DELETE FROM ' + RTRIM(@c_TableName) + 
         ' WHERE TransmitLogKey = @c_TransmitLogKey ' +
         ' AND ArchiveCop = ''9'' '
      
      EXEC sp_ExecuteSQL @c_SQLStatement, N'@c_TransmitLogKey   NVARCHAR(10)', @c_TransmitLogKey
            
   
      SELECT @nRowCount = @nRowCount + 1
      
      FETCH FROM CUR_TRANSMITLOG INTO @c_TableName, @c_TransmitLogKey
   END
   
   CLOSE CUR_TRANSMITLOG
   DEALLOCATE CUR_TRANSMITLOG

   PRINT '*** ' + CONVERT(NVARCHAR(12), @nRowCount) + ' TRANSMITLOG Archived ***' 

   EXIT_SP:
END -- Procedure 

GO