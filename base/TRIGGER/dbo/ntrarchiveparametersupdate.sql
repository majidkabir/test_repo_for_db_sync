SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************/
/* Trigger: ntrARCHIVEPARAMETERSUpdate                            */
/* Creation Date:  17-Aug-2022                                    */
/* Copyright: IDS                                                 */
/* Written by:  kelvinongcy                                       */
/*                                                                */
/* Purpose: ARCHIVEPARAMETERS Update                              */
/* Data Modifications:                                            */
/*                                                                */
/* Updates:                                                       */
/* Date         Author    	  Ver   Purposes                       */
/* 2022-08-17   kelvinongcy  1.0   Capture editwho, editdate      */
/*                                 and modification into log      */
/******************************************************************/  
  
CREATE     TRIGGER [dbo].[ntrArchiveParametersUpdate]  
ON [dbo].[ARCHIVEPARAMETERS]  
FOR UPDATE  
AS   
BEGIN  
   IF @@ROWCOUNT = 0  
   BEGIN  
      RETURN  
   END     
      SET NOCOUNT ON  
      SET ANSI_NULLS OFF  
      SET QUOTED_IDENTIFIER OFF  
      SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_err          int       -- Error number returned by stored procedure or this trigger  
           ,@c_errmsg      NVARCHAR(250) -- Error message returned by stored procedure or this trigger  
           ,@n_continue    int                   
           ,@n_starttcnt   int                -- Holds the current transaction count  
           ,@n_cnt         int
           ,@c_ArchiveKey  nvarchar(10)
           ,@c_Column      nvarchar(255)
           ,@c_OldValue    nvarchar(255)
           ,@c_NewValue    nvarchar(255)
   
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  
  
   IF UPDATE(ArchiveCop)  
   BEGIN  
      SELECT @n_continue = 4   
   END 
         
   IF ( @n_continue = 1 or @n_continue=2 ) AND NOT UPDATE(EditDate)  
   BEGIN  
      UPDATE ARCHIVEPARAMETERS  
      SET EditDate = GETDATE(),  
          EditWho  = SUSER_SNAME(),  
          TrafficCop = NULL   
      FROM dbo.ARCHIVEPARAMETERS, INSERTED  
      WHERE ARCHIVEPARAMETERS.ArchiveKey = INSERTED.ArchiveKey  
  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  

      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62303   -- Should Be Set To The SQL Err message but I don't know how to do so.  
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": UPDATE Failed on ARCHIVEPARAMETERS table. (ntrARCHIVEPARAMETERSUpdate)"   
                        + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "  
      END  
   END 

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT ArchiveKey, [Column], OldValue
      INTO #DELETED
      FROM 
         (  SELECT CAST([Archivekey] AS NVARCHAR) AS [Archivekey],CAST([CopyRowsToArchiveDatabase] AS NVARCHAR) AS [CopyRowsToArchiveDatabase],CAST([ArchiveDataBaseName] AS NVARCHAR) AS [ArchiveDataBaseName],
                   CAST([LiveDataBaseName] AS NVARCHAR) AS [LiveDataBaseName],CAST([ShipNumberofDaysToRetain] AS NVARCHAR) AS [ShipNumberofDaysToRetain],CAST([ShipActive] AS NVARCHAR) AS [ShipActive],
                   CAST([ShipStorerKeyStart] AS NVARCHAR) AS [ShipStorerKeyStart],CAST([ShipStorerKeyEnd] AS NVARCHAR) AS [ShipStorerKeyEnd],CAST([ShipSysOrdStart] AS NVARCHAR) AS [ShipSysOrdStart],
                   CAST([ShipSysOrdEnd] AS NVARCHAR) AS [ShipSysOrdEnd],CAST([ShipExternOrderKeyStart] AS NVARCHAR) AS [ShipExternOrderKeyStart],CAST([ShipExternOrderKeyEnd] AS NVARCHAR) AS [ShipExternOrderKeyEnd],
                   CAST([ShipOrdTypStart] AS NVARCHAR) AS [ShipOrdTypStart],CAST([ShipOrdTypEnd] AS NVARCHAR) AS [ShipOrdTypEnd],CAST([ShipOrdGrpStart] AS NVARCHAR) AS [ShipOrdGrpStart],
                   CAST([ShipOrdGrpEnd] AS NVARCHAR) AS [ShipOrdGrpEnd],CAST([ShipToStart] AS NVARCHAR) AS [ShipToStart],CAST([ShipToEnd] AS NVARCHAR) AS [ShipToEnd],CAST([ShipBillToStart] AS NVARCHAR) AS [ShipBillToStart],
                   CAST([ShipBillToEnd] AS NVARCHAR) AS [ShipBillToEnd],CAST([ShipmentOrderDateType] AS NVARCHAR) AS [ShipmentOrderDateType],CAST([AdjNumberofDaysToRetain] AS NVARCHAR) AS [AdjNumberofDaysToRetain],
                   CAST([AdjActive] AS NVARCHAR) AS [AdjActive],CAST([AdjStart] AS NVARCHAR) AS [AdjStart],CAST([AdjEnd] AS NVARCHAR) AS [AdjEnd],CAST([AdjustmentDateType] AS NVARCHAR) AS [AdjustmentDateType],
                   CAST([TranNumberofDaysToRetain] AS NVARCHAR) AS [TranNumberofDaysToRetain],CAST([TranActive] AS NVARCHAR) AS [TranActive],CAST([TranStart] AS NVARCHAR) AS [TranStart],
                   CAST([TranEnd] AS NVARCHAR) AS [TranEnd],CAST([TransferDateType] AS NVARCHAR) AS [TransferDateType],CAST([PONumberofDaysToRetain] AS NVARCHAR) AS [PONumberofDaysToRetain],
                   CAST([POActive] AS NVARCHAR) AS [POActive],CAST([POStorerKeyStart] AS NVARCHAR) AS [POStorerKeyStart],CAST([POStorerKeyEnd] AS NVARCHAR) AS [POStorerKeyEnd],CAST([POStart] AS NVARCHAR) AS [POStart],
                   CAST([POEnd] AS NVARCHAR) AS [POEnd],CAST([PODateType] AS NVARCHAR) AS [PODateType],CAST([ReceiptNumberofDaysToRetain] AS NVARCHAR) AS [ReceiptNumberofDaysToRetain],
                   CAST([ReceiptActive] AS NVARCHAR) AS [ReceiptActive],CAST([ReceiptStorerKeyStart] AS NVARCHAR) AS [ReceiptStorerKeyStart],CAST([ReceiptStorerKeyEnd] AS NVARCHAR) AS [ReceiptStorerKeyEnd],
                   CAST([ReceiptStart] AS NVARCHAR) AS [ReceiptStart],CAST([ReceiptEnd] AS NVARCHAR) AS [ReceiptEnd],CAST([ReceiptDateType] AS NVARCHAR) AS [ReceiptDateType],
                   CAST([ItrnNumberofDaysToRetain] AS NVARCHAR) AS [ItrnNumberofDaysToRetain],CAST([ItrnActive] AS NVARCHAR) AS [ItrnActive],CAST([ItrnStorerKeyStart] AS NVARCHAR) AS [ItrnStorerKeyStart],
                   CAST([ItrnStorerKeyEnd] AS NVARCHAR) AS [ItrnStorerKeyEnd],CAST([ItrnSkuStart] AS NVARCHAR) AS [ItrnSkuStart],CAST([ItrnSkuEnd] AS NVARCHAR) AS [ItrnSkuEnd],
                   CAST([ItrnLotStart] AS NVARCHAR) AS [ItrnLotStart],CAST([ItrnLotEnd] AS NVARCHAR) AS [ItrnLotEnd],CAST([ItrnDateType] AS NVARCHAR) AS [ItrnDateType],
                   CAST([MAWBNumberofDaysToRetain] AS NVARCHAR) AS [MAWBNumberofDaysToRetain],CAST([MAWBActive] AS NVARCHAR) AS [MAWBActive],CAST([MAWBStart] AS NVARCHAR) AS [MAWBStart],
                   CAST([MAWBEnd] AS NVARCHAR) AS [MAWBEnd],CAST([MAWBDateType] AS NVARCHAR) AS [MAWBDateType],CAST([HAWBNumberofDaysToRetain] AS NVARCHAR) AS [HAWBNumberofDaysToRetain],
                   CAST([HAWBActive] AS NVARCHAR) AS [HAWBActive],CAST([HAWBStart] AS NVARCHAR) AS [HAWBStart],CAST([HAWBEnd] AS NVARCHAR) AS [HAWBEnd],CAST([HAWBDateType] AS NVARCHAR) AS [HAWBDateType],
                   CAST([ContainerNumberofDaysToRetain] AS NVARCHAR) AS [ContainerNumberofDaysToRetain],CAST([ContainerActive] AS NVARCHAR) AS [ContainerActive],CAST([ContainerStart] AS NVARCHAR) AS [ContainerStart],
                   CAST([ContainerEnd] AS NVARCHAR) AS [ContainerEnd],CAST([ContainerDateType] AS NVARCHAR) AS [ContainerDateType],CAST([PalletNumberofDaysToRetain] AS NVARCHAR) AS [PalletNumberofDaysToRetain],
                   CAST([PalletActive] AS NVARCHAR) AS [PalletActive],CAST([PalletStart] AS NVARCHAR) AS [PalletStart],CAST([PalletEnd] AS NVARCHAR) AS [PalletEnd],CAST([PalletDateType] AS NVARCHAR) AS [PalletDateType],
                   CAST([CaseMNumberofDaysToRetain] AS NVARCHAR) AS [CaseMNumberofDaysToRetain],CAST([CaseMActive] AS NVARCHAR) AS [CaseMActive],CAST([CaseMStorerKeyStart] AS NVARCHAR) AS [CaseMStorerKeyStart],
                   CAST([CaseMStorerKeyEnd] AS NVARCHAR) AS [CaseMStorerKeyEnd],CAST([CaseMStart] AS NVARCHAR) AS [CaseMStart],CAST([CaseMEnd] AS NVARCHAR) AS [CaseMEnd],CAST([CaseMDateType] AS NVARCHAR) AS [CaseMDateType],
                   CAST([MbolNumberofDaysToRetain] AS NVARCHAR) AS [MbolNumberofDaysToRetain],CAST([MbolActive] AS NVARCHAR) AS [MbolActive],CAST([MbolStart] AS NVARCHAR) AS [MbolStart],
                   CAST([MbolEnd] AS NVARCHAR) AS [MbolEnd],CAST([MBOLDepDateStart] AS NVARCHAR) AS [MBOLDepDateStart],CAST([MBOLDepDateEnd] AS NVARCHAR) AS [MBOLDepDateEnd],
                   CAST([MBOLDelDateStart] AS NVARCHAR) AS [MBOLDelDateStart],CAST([MBOLDelDateEnd] AS NVARCHAR) AS [MBOLDelDateEnd],CAST([MbolVoyageStart] AS NVARCHAR) AS [MbolVoyageStart],
                   CAST([MbolVoyageEnd] AS NVARCHAR) AS [MbolVoyageEnd],CAST([MBOLDateType] AS NVARCHAR) AS [MBOLDateType],CAST([PickDateType] AS NVARCHAR) AS [PickDateType],
                   /*CAST([AddDate] AS NVARCHAR) AS [AddDate], CAST([AddWho] AS NVARCHAR) AS [AddWho],CAST([EditDate] AS NVARCHAR) AS [EditDate],CAST([EditWho] AS NVARCHAR) AS [EditWho], */
                   CAST([TrafficCop] AS NVARCHAR) AS [TrafficCop], CAST([ArchiveCop] AS NVARCHAR) AS [ArchiveCop],
                   CAST([CCNumberofDaysToRetain] AS NVARCHAR) AS [CCNumberofDaysToRetain],
                   CAST([CCActive] AS NVARCHAR) AS [CCActive],CAST([CCStart] AS NVARCHAR) AS [CCStart],CAST([CCEnd] AS NVARCHAR) AS [CCEnd],CAST([CCDateType] AS NVARCHAR) AS [CCDateType],
                   CAST([AlertNumberofDaysToRetain] AS NVARCHAR) AS [AlertNumberofDaysToRetain],CAST([AlertActive] AS NVARCHAR) AS [AlertActive],CAST([AlertStart] AS NVARCHAR) AS [AlertStart],
                   CAST([AlertEnd] AS NVARCHAR) AS [AlertEnd],CAST([AlertDateType] AS NVARCHAR) AS [AlertDateType],CAST([RFDBLogNumberofDaysToRetain] AS NVARCHAR) AS [RFDBLogNumberofDaysToRetain],
                   CAST([RFDBLogActive] AS NVARCHAR) AS [RFDBLogActive],CAST([RFDBLogDateType] AS NVARCHAR) AS [RFDBLogDateType],CAST([SKULogNumberofDaysToRetain] AS NVARCHAR) AS [SKULogNumberofDaysToRetain],
                   CAST([SKULogActive] AS NVARCHAR) AS [SKULogActive],CAST([SKULogDateType] AS NVARCHAR) AS [SKULogDateType],CAST([ErrLogNumberofDaysToRetain] AS NVARCHAR) AS [ErrLogNumberofDaysToRetain],
                   CAST([ErrLogActive] AS NVARCHAR) AS [ErrLogActive],CAST([ErrLogDateType] AS NVARCHAR) AS [ErrLogDateType],CAST([PackLogNumberofDaysToRetain] AS NVARCHAR) AS [PackLogNumberofDaysToRetain],
                   CAST([PackLogActive] AS NVARCHAR) AS [PackLogActive],CAST([PackLogStart] AS NVARCHAR) AS [PackLogStart],CAST([PackLogEnd] AS NVARCHAR) AS [PackLogEnd],
                   CAST([PackLogDateType] AS NVARCHAR) AS [PackLogDateType],CAST([TranmLogNumberofDaysToRetain] AS NVARCHAR) AS [TranmLogNumberofDaysToRetain],CAST([TranmLogActive] AS NVARCHAR) AS [TranmLogActive],
                   CAST([TranmLogStart] AS NVARCHAR) AS [TranmLogStart],CAST([TranmLogEnd] AS NVARCHAR) AS [TranmLogEnd],CAST([TranmLogDateType] AS NVARCHAR) AS [TranmLogDateType],
                   CAST([OrdersLogNumberofDaysToRetain] AS NVARCHAR) AS [OrdersLogNumberofDaysToRetain],CAST([OrdersLogActive] AS NVARCHAR) AS [OrdersLogActive],CAST([OrdersLogStart] AS NVARCHAR) AS [OrdersLogStart],
                   CAST([OrdersLogEnd] AS NVARCHAR) AS [OrdersLogEnd],CAST([OrdersLogDateType] AS NVARCHAR) AS [OrdersLogDateType],CAST([InvrptLogNumberofDaysToRetain] AS NVARCHAR) AS [InvrptLogNumberofDaysToRetain],
                   CAST([InvrptLogActive] AS NVARCHAR) AS [InvrptLogActive],CAST([InvrptLogStart] AS NVARCHAR) AS [InvrptLogStart],CAST([InvrptLogEnd] AS NVARCHAR) AS [InvrptLogEnd],
                   CAST([InvrptLogDateType] AS NVARCHAR) AS [InvrptLogDateType],CAST([TrigLogNumberofDaysToRetain] AS NVARCHAR) AS [TrigLogNumberofDaysToRetain],CAST([TrigLogActive] AS NVARCHAR) AS [TrigLogActive],
                   CAST([TrigLogStart] AS NVARCHAR) AS [TrigLogStart],CAST([TrigLogEnd] AS NVARCHAR) AS [TrigLogEnd],CAST([TrigLogDateType] AS NVARCHAR) AS [TrigLogDateType],
                   CAST([PTraceNumberofDaysToRetain] AS NVARCHAR) AS [PTraceNumberofDaysToRetain],CAST([PTraceActive] AS NVARCHAR) AS [PTraceActive],CAST([PTraceStart] AS NVARCHAR) AS [PTraceStart],
                   CAST([PTraceEnd] AS NVARCHAR) AS [PTraceEnd],CAST([PTraceDateType] AS NVARCHAR) AS [PTraceDateType],CAST([REPLENISHNumberofDaysToRetain] AS NVARCHAR) AS [REPLENISHNumberofDaysToRetain],
                   CAST([REPLENISHActive] AS NVARCHAR) AS [REPLENISHActive],CAST([REPLENISHStart] AS NVARCHAR) AS [REPLENISHStart],CAST([REPLENISHEnd] AS NVARCHAR) AS [REPLENISHEnd],
                   CAST([REPLENISHDateType] AS NVARCHAR) AS [REPLENISHDateType],CAST([IDActive] AS NVARCHAR) AS [IDActive],CAST([IDStart] AS NVARCHAR) AS [IDStart],CAST([IDEnd] AS NVARCHAR) AS [IDEnd],
                   CAST([InvQCNumberofDaysToRetain] AS NVARCHAR) AS [InvQCNumberofDaysToRetain],CAST([InvQCActive] AS NVARCHAR) AS [InvQCActive],CAST([InvQCStart] AS NVARCHAR) AS [InvQCStart],
                   CAST([InvQCEnd] AS NVARCHAR) AS [InvQCEnd],CAST([InvQCDateType] AS NVARCHAR) AS [InvQCDateType],CAST([InvHoldNumberofDaysToRetain] AS NVARCHAR) AS [InvHoldNumberofDaysToRetain],
                   CAST([InvHoldActive] AS NVARCHAR) AS [InvHoldActive],CAST([InvHoldStart] AS NVARCHAR) AS [InvHoldStart],CAST([InvHoldEnd] AS NVARCHAR) AS [InvHoldEnd],
                   CAST([InvHoldDateType] AS NVARCHAR) AS [InvHoldDateType],CAST([PLSNumberofDaysToRetain] AS NVARCHAR) AS [PLSNumberofDaysToRetain],CAST([PLSActive] AS NVARCHAR) AS [PLSActive],
                   CAST([PLSStart] AS NVARCHAR) AS [PLSStart],CAST([PLSEnd] AS NVARCHAR) AS [PLSEnd],CAST([PLSDateType] AS NVARCHAR) AS [PLSDateType],CAST([KITNumberofDaysToRetain] AS NVARCHAR) AS [KITNumberofDaysToRetain],
                   CAST([KITActive] AS NVARCHAR) AS [KITActive],CAST([KITStart] AS NVARCHAR) AS [KITStart],CAST([KITEnd] AS NVARCHAR) AS [KITEnd],CAST([KITDateType] AS NVARCHAR) AS [KITDateType],
                   CAST([GUINumberofDaysToRetain] AS NVARCHAR) AS [GUINumberofDaysToRetain],CAST([GUIActive] AS NVARCHAR) AS [GUIActive],CAST([GUIInvoiceNoStart] AS NVARCHAR) AS [GUIInvoiceNoStart],
                   CAST([GUIInvoiceNoEnd] AS NVARCHAR) AS [GUIInvoiceNoEnd],CAST([GUIDateType] AS NVARCHAR) AS [GUIDateType],CAST([RdsPoNumberofDaysToRetain] AS NVARCHAR) AS [RdsPoNumberofDaysToRetain],
                   CAST([RdsPodatetype] AS NVARCHAR) AS [RdsPodatetype],CAST([RdsPoActive] AS NVARCHAR) AS [RdsPoActive],CAST([RdsPoStart] AS NVARCHAR) AS [RdsPoStart],CAST([RdsPoEnd] AS NVARCHAR) AS [RdsPoEnd],
                   CAST([RdsOrdersNumberofDaysToRetain] AS NVARCHAR) AS [RdsOrdersNumberofDaysToRetain],CAST([RdsOrdersdatetype] AS NVARCHAR) AS [RdsOrdersdatetype],CAST([RdsOrdersActive] AS NVARCHAR) AS [RdsOrdersActive],
                   CAST([RdsOrdersStart] AS NVARCHAR) AS [RdsOrdersStart],CAST([RdsOrdersEnd] AS NVARCHAR) AS [RdsOrdersEnd],CAST([DailyInvNoofDaysToRetain] AS NVARCHAR) AS [DailyInvNoofDaysToRetain],
                   CAST([DailyInvActive] AS NVARCHAR) AS [DailyInvActive],CAST([DailyInvStart] AS NVARCHAR) AS [DailyInvStart],CAST([DailyInvEnd] AS NVARCHAR) AS [DailyInvEnd],
                   CAST([DailyInvDateType] AS NVARCHAR) AS [DailyInvDateType],CAST([DelPickslipNoofDaysToRetain] AS NVARCHAR) AS [DelPickslipNoofDaysToRetain],CAST([DelPickslipActive] AS NVARCHAR) AS [DelPickslipActive],
                   CAST([DelPickslipStart] AS NVARCHAR) AS [DelPickslipStart],CAST([DelPickslipEnd] AS NVARCHAR) AS [DelPickslipEnd],CAST([DelPickslipDateType] AS NVARCHAR) AS [DelPickslipDateType],
                   CAST([SMSPODNumberofDaysToRetain] AS NVARCHAR) AS [SMSPODNumberofDaysToRetain],CAST([SMSPODActive] AS NVARCHAR) AS [SMSPODActive],CAST([SMSPODDateType] AS NVARCHAR) AS [SMSPODDateType]  
                   FROM DELETED WITH (NOLOCK) ) pvt
            UNPIVOT
            (
               OldValue FOR [Column]  IN 
               (  [CopyRowsToArchiveDatabase],[ArchiveDataBaseName],[LiveDataBaseName],[ShipNumberofDaysToRetain],[ShipActive],[ShipStorerKeyStart],[ShipStorerKeyEnd],  
                  [ShipSysOrdStart],[ShipSysOrdEnd],[ShipExternOrderKeyStart],[ShipExternOrderKeyEnd],[ShipOrdTypStart],[ShipOrdTypEnd],[ShipOrdGrpStart],[ShipOrdGrpEnd],
                  [ShipToStart],[ShipToEnd], [ShipBillToStart],[ShipBillToEnd],[ShipmentOrderDateType],[AdjNumberofDaysToRetain],[AdjActive],[AdjStart],[AdjEnd],[AdjustmentDateType],
                  [TranNumberofDaysToRetain],[TranActive],[TranStart],[TranEnd],[TransferDateType],  
                  [PONumberofDaysToRetain],[POActive],[POStorerKeyStart],[POStorerKeyEnd],[POStart],[POEnd],[PODateType],  
                  [ReceiptNumberofDaysToRetain],[ReceiptActive],[ReceiptStorerKeyStart],[ReceiptStorerKeyEnd],[ReceiptStart],[ReceiptEnd],[ReceiptDateType],  
                  [ItrnNumberofDaysToRetain],[ItrnActive],[ItrnStorerKeyStart],[ItrnStorerKeyEnd],[ItrnSkuStart],[ItrnSkuEnd],[ItrnLotStart],[ItrnLotEnd],[ItrnDateType],  
                  [MAWBNumberofDaysToRetain],[MAWBActive],[MAWBStart],[MAWBEnd],[MAWBDateType],[HAWBNumberofDaysToRetain],[HAWBActive],[HAWBStart],[HAWBEnd],[HAWBDateType],  
                  [ContainerNumberofDaysToRetain],[ContainerActive],[ContainerStart],[ContainerEnd],[ContainerDateType],
                  [PalletNumberofDaysToRetain],[PalletActive],[PalletStart],[PalletEnd],[PalletDateType],
                  [CaseMNumberofDaysToRetain],[CaseMActive],[CaseMStorerKeyStart],[CaseMStorerKeyEnd],[CaseMStart],[CaseMEnd],[CaseMDateType],
                  [MbolNumberofDaysToRetain],[MbolActive],[MbolStart],[MbolEnd],[MBOLDepDateStart],[MBOLDepDateEnd],[MBOLDelDateStart],[MBOLDelDateEnd],[MbolVoyageStart],[MbolVoyageEnd],
                  [MBOLDateType],[PickDateType] /*,[AddDate],[AddWho],[EditDate],[EditWho]*/,[TrafficCop],[ArchiveCop],  
                  [CCNumberofDaysToRetain],[CCActive],[CCStart],[CCEnd],[CCDateType],  
                  [AlertNumberofDaysToRetain],[AlertActive],[AlertStart],[AlertEnd],[AlertDateType], [RFDBLogNumberofDaysToRetain],[RFDBLogActive],[RFDBLogDateType],  
                  [SKULogNumberofDaysToRetain],[SKULogActive],[SKULogDateType],[ErrLogNumberofDaysToRetain],[ErrLogActive],[ErrLogDateType],  
                  [PackLogNumberofDaysToRetain],[PackLogActive],[PackLogStart],[PackLogEnd],[PackLogDateType],  
                  [TranmLogNumberofDaysToRetain],[TranmLogActive],[TranmLogStart],[TranmLogEnd],[TranmLogDateType],  
                  [OrdersLogNumberofDaysToRetain],[OrdersLogActive],[OrdersLogStart],[OrdersLogEnd],[OrdersLogDateType],  
                  [InvrptLogNumberofDaysToRetain],[InvrptLogActive],[InvrptLogStart],[InvrptLogEnd],[InvrptLogDateType],  
                  [TrigLogNumberofDaysToRetain],[TrigLogActive],[TrigLogStart],[TrigLogEnd],[TrigLogDateType],  
                  [PTraceNumberofDaysToRetain],[PTraceActive],[PTraceStart],[PTraceEnd],[PTraceDateType],  
                  [REPLENISHNumberofDaysToRetain],[REPLENISHActive],[REPLENISHStart],[REPLENISHEnd],[REPLENISHDateType],  
                  [IDActive],[IDStart],[IDEnd],[InvQCNumberofDaysToRetain],[InvQCActive],[InvQCStart],[InvQCEnd],[InvQCDateType],[InvHoldNumberofDaysToRetain],[InvHoldActive],
                  [InvHoldStart],[InvHoldEnd],[InvHoldDateType],  
                  [PLSNumberofDaysToRetain],[PLSActive],[PLSStart],[PLSEnd],[PLSDateType],  
                  [KITNumberofDaysToRetain],[KITActive],[KITStart],[KITEnd],[KITDateType],  
                  [GUINumberofDaysToRetain],[GUIActive],[GUIInvoiceNoStart],[GUIInvoiceNoEnd],[GUIDateType],  
                  [RdsPoNumberofDaysToRetain],[RdsPodatetype],[RdsPoActive],[RdsPoStart],[RdsPoEnd],[RdsOrdersNumberofDaysToRetain],[RdsOrdersdatetype],[RdsOrdersActive],
                  [RdsOrdersStart],[RdsOrdersEnd],  
                  [DailyInvNoofDaysToRetain],[DailyInvActive],[DailyInvStart],[DailyInvEnd],[DailyInvDateType],[DelPickslipNoofDaysToRetain],[DelPickslipActive],[DelPickslipStart],
                  [DelPickslipEnd],[DelPickslipDateType],  
                  [SMSPODNumberofDaysToRetain],[SMSPODActive],[SMSPODDateType] 
               )             
            ) AS unpvt 

      SELECT ArchiveKey, [Column], NewValue
      INTO #INSERTED
      FROM 
         (  SELECT CAST([Archivekey] AS NVARCHAR) AS [Archivekey],CAST([CopyRowsToArchiveDatabase] AS NVARCHAR) AS [CopyRowsToArchiveDatabase],CAST([ArchiveDataBaseName] AS NVARCHAR) AS [ArchiveDataBaseName],
                   CAST([LiveDataBaseName] AS NVARCHAR) AS [LiveDataBaseName],CAST([ShipNumberofDaysToRetain] AS NVARCHAR) AS [ShipNumberofDaysToRetain],CAST([ShipActive] AS NVARCHAR) AS [ShipActive],
                   CAST([ShipStorerKeyStart] AS NVARCHAR) AS [ShipStorerKeyStart],CAST([ShipStorerKeyEnd] AS NVARCHAR) AS [ShipStorerKeyEnd],CAST([ShipSysOrdStart] AS NVARCHAR) AS [ShipSysOrdStart],
                   CAST([ShipSysOrdEnd] AS NVARCHAR) AS [ShipSysOrdEnd],CAST([ShipExternOrderKeyStart] AS NVARCHAR) AS [ShipExternOrderKeyStart],CAST([ShipExternOrderKeyEnd] AS NVARCHAR) AS [ShipExternOrderKeyEnd],
                   CAST([ShipOrdTypStart] AS NVARCHAR) AS [ShipOrdTypStart],CAST([ShipOrdTypEnd] AS NVARCHAR) AS [ShipOrdTypEnd],CAST([ShipOrdGrpStart] AS NVARCHAR) AS [ShipOrdGrpStart],
                   CAST([ShipOrdGrpEnd] AS NVARCHAR) AS [ShipOrdGrpEnd],CAST([ShipToStart] AS NVARCHAR) AS [ShipToStart],CAST([ShipToEnd] AS NVARCHAR) AS [ShipToEnd],CAST([ShipBillToStart] AS NVARCHAR) AS [ShipBillToStart],
                   CAST([ShipBillToEnd] AS NVARCHAR) AS [ShipBillToEnd],CAST([ShipmentOrderDateType] AS NVARCHAR) AS [ShipmentOrderDateType],CAST([AdjNumberofDaysToRetain] AS NVARCHAR) AS [AdjNumberofDaysToRetain],
                   CAST([AdjActive] AS NVARCHAR) AS [AdjActive],CAST([AdjStart] AS NVARCHAR) AS [AdjStart],CAST([AdjEnd] AS NVARCHAR) AS [AdjEnd],CAST([AdjustmentDateType] AS NVARCHAR) AS [AdjustmentDateType],
                   CAST([TranNumberofDaysToRetain] AS NVARCHAR) AS [TranNumberofDaysToRetain],CAST([TranActive] AS NVARCHAR) AS [TranActive],CAST([TranStart] AS NVARCHAR) AS [TranStart],
                   CAST([TranEnd] AS NVARCHAR) AS [TranEnd],CAST([TransferDateType] AS NVARCHAR) AS [TransferDateType],CAST([PONumberofDaysToRetain] AS NVARCHAR) AS [PONumberofDaysToRetain],
                   CAST([POActive] AS NVARCHAR) AS [POActive],CAST([POStorerKeyStart] AS NVARCHAR) AS [POStorerKeyStart],CAST([POStorerKeyEnd] AS NVARCHAR) AS [POStorerKeyEnd],CAST([POStart] AS NVARCHAR) AS [POStart],
                   CAST([POEnd] AS NVARCHAR) AS [POEnd],CAST([PODateType] AS NVARCHAR) AS [PODateType],CAST([ReceiptNumberofDaysToRetain] AS NVARCHAR) AS [ReceiptNumberofDaysToRetain],
                   CAST([ReceiptActive] AS NVARCHAR) AS [ReceiptActive],CAST([ReceiptStorerKeyStart] AS NVARCHAR) AS [ReceiptStorerKeyStart],CAST([ReceiptStorerKeyEnd] AS NVARCHAR) AS [ReceiptStorerKeyEnd],
                   CAST([ReceiptStart] AS NVARCHAR) AS [ReceiptStart],CAST([ReceiptEnd] AS NVARCHAR) AS [ReceiptEnd],CAST([ReceiptDateType] AS NVARCHAR) AS [ReceiptDateType],
                   CAST([ItrnNumberofDaysToRetain] AS NVARCHAR) AS [ItrnNumberofDaysToRetain],CAST([ItrnActive] AS NVARCHAR) AS [ItrnActive],CAST([ItrnStorerKeyStart] AS NVARCHAR) AS [ItrnStorerKeyStart],
                   CAST([ItrnStorerKeyEnd] AS NVARCHAR) AS [ItrnStorerKeyEnd],CAST([ItrnSkuStart] AS NVARCHAR) AS [ItrnSkuStart],CAST([ItrnSkuEnd] AS NVARCHAR) AS [ItrnSkuEnd],
                   CAST([ItrnLotStart] AS NVARCHAR) AS [ItrnLotStart],CAST([ItrnLotEnd] AS NVARCHAR) AS [ItrnLotEnd],CAST([ItrnDateType] AS NVARCHAR) AS [ItrnDateType],
                   CAST([MAWBNumberofDaysToRetain] AS NVARCHAR) AS [MAWBNumberofDaysToRetain],CAST([MAWBActive] AS NVARCHAR) AS [MAWBActive],CAST([MAWBStart] AS NVARCHAR) AS [MAWBStart],
                   CAST([MAWBEnd] AS NVARCHAR) AS [MAWBEnd],CAST([MAWBDateType] AS NVARCHAR) AS [MAWBDateType],CAST([HAWBNumberofDaysToRetain] AS NVARCHAR) AS [HAWBNumberofDaysToRetain],
                   CAST([HAWBActive] AS NVARCHAR) AS [HAWBActive],CAST([HAWBStart] AS NVARCHAR) AS [HAWBStart],CAST([HAWBEnd] AS NVARCHAR) AS [HAWBEnd],CAST([HAWBDateType] AS NVARCHAR) AS [HAWBDateType],
                   CAST([ContainerNumberofDaysToRetain] AS NVARCHAR) AS [ContainerNumberofDaysToRetain],CAST([ContainerActive] AS NVARCHAR) AS [ContainerActive],CAST([ContainerStart] AS NVARCHAR) AS [ContainerStart],
                   CAST([ContainerEnd] AS NVARCHAR) AS [ContainerEnd],CAST([ContainerDateType] AS NVARCHAR) AS [ContainerDateType],CAST([PalletNumberofDaysToRetain] AS NVARCHAR) AS [PalletNumberofDaysToRetain],
                   CAST([PalletActive] AS NVARCHAR) AS [PalletActive],CAST([PalletStart] AS NVARCHAR) AS [PalletStart],CAST([PalletEnd] AS NVARCHAR) AS [PalletEnd],CAST([PalletDateType] AS NVARCHAR) AS [PalletDateType],
                   CAST([CaseMNumberofDaysToRetain] AS NVARCHAR) AS [CaseMNumberofDaysToRetain],CAST([CaseMActive] AS NVARCHAR) AS [CaseMActive],CAST([CaseMStorerKeyStart] AS NVARCHAR) AS [CaseMStorerKeyStart],
                   CAST([CaseMStorerKeyEnd] AS NVARCHAR) AS [CaseMStorerKeyEnd],CAST([CaseMStart] AS NVARCHAR) AS [CaseMStart],CAST([CaseMEnd] AS NVARCHAR) AS [CaseMEnd],CAST([CaseMDateType] AS NVARCHAR) AS [CaseMDateType],
                   CAST([MbolNumberofDaysToRetain] AS NVARCHAR) AS [MbolNumberofDaysToRetain],CAST([MbolActive] AS NVARCHAR) AS [MbolActive],CAST([MbolStart] AS NVARCHAR) AS [MbolStart],
                   CAST([MbolEnd] AS NVARCHAR) AS [MbolEnd],CAST([MBOLDepDateStart] AS NVARCHAR) AS [MBOLDepDateStart],CAST([MBOLDepDateEnd] AS NVARCHAR) AS [MBOLDepDateEnd],
                   CAST([MBOLDelDateStart] AS NVARCHAR) AS [MBOLDelDateStart],CAST([MBOLDelDateEnd] AS NVARCHAR) AS [MBOLDelDateEnd],CAST([MbolVoyageStart] AS NVARCHAR) AS [MbolVoyageStart],
                   CAST([MbolVoyageEnd] AS NVARCHAR) AS [MbolVoyageEnd],CAST([MBOLDateType] AS NVARCHAR) AS [MBOLDateType],CAST([PickDateType] AS NVARCHAR) AS [PickDateType],
                   /*CAST([AddDate] AS NVARCHAR) AS [AddDate], CAST([AddWho] AS NVARCHAR) AS [AddWho],CAST([EditDate] AS NVARCHAR) AS [EditDate],CAST([EditWho] AS NVARCHAR) AS [EditWho], */
                   CAST([TrafficCop] AS NVARCHAR) AS [TrafficCop], CAST([ArchiveCop] AS NVARCHAR) AS [ArchiveCop],
                   CAST([CCNumberofDaysToRetain] AS NVARCHAR) AS [CCNumberofDaysToRetain],
                   CAST([CCActive] AS NVARCHAR) AS [CCActive],CAST([CCStart] AS NVARCHAR) AS [CCStart],CAST([CCEnd] AS NVARCHAR) AS [CCEnd],CAST([CCDateType] AS NVARCHAR) AS [CCDateType],
                   CAST([AlertNumberofDaysToRetain] AS NVARCHAR) AS [AlertNumberofDaysToRetain],CAST([AlertActive] AS NVARCHAR) AS [AlertActive],CAST([AlertStart] AS NVARCHAR) AS [AlertStart],
                   CAST([AlertEnd] AS NVARCHAR) AS [AlertEnd],CAST([AlertDateType] AS NVARCHAR) AS [AlertDateType],CAST([RFDBLogNumberofDaysToRetain] AS NVARCHAR) AS [RFDBLogNumberofDaysToRetain],
                   CAST([RFDBLogActive] AS NVARCHAR) AS [RFDBLogActive],CAST([RFDBLogDateType] AS NVARCHAR) AS [RFDBLogDateType],CAST([SKULogNumberofDaysToRetain] AS NVARCHAR) AS [SKULogNumberofDaysToRetain],
                   CAST([SKULogActive] AS NVARCHAR) AS [SKULogActive],CAST([SKULogDateType] AS NVARCHAR) AS [SKULogDateType],CAST([ErrLogNumberofDaysToRetain] AS NVARCHAR) AS [ErrLogNumberofDaysToRetain],
                   CAST([ErrLogActive] AS NVARCHAR) AS [ErrLogActive],CAST([ErrLogDateType] AS NVARCHAR) AS [ErrLogDateType],CAST([PackLogNumberofDaysToRetain] AS NVARCHAR) AS [PackLogNumberofDaysToRetain],
                   CAST([PackLogActive] AS NVARCHAR) AS [PackLogActive],CAST([PackLogStart] AS NVARCHAR) AS [PackLogStart],CAST([PackLogEnd] AS NVARCHAR) AS [PackLogEnd],
                   CAST([PackLogDateType] AS NVARCHAR) AS [PackLogDateType],CAST([TranmLogNumberofDaysToRetain] AS NVARCHAR) AS [TranmLogNumberofDaysToRetain],CAST([TranmLogActive] AS NVARCHAR) AS [TranmLogActive],
                   CAST([TranmLogStart] AS NVARCHAR) AS [TranmLogStart],CAST([TranmLogEnd] AS NVARCHAR) AS [TranmLogEnd],CAST([TranmLogDateType] AS NVARCHAR) AS [TranmLogDateType],
                   CAST([OrdersLogNumberofDaysToRetain] AS NVARCHAR) AS [OrdersLogNumberofDaysToRetain],CAST([OrdersLogActive] AS NVARCHAR) AS [OrdersLogActive],CAST([OrdersLogStart] AS NVARCHAR) AS [OrdersLogStart],
                   CAST([OrdersLogEnd] AS NVARCHAR) AS [OrdersLogEnd],CAST([OrdersLogDateType] AS NVARCHAR) AS [OrdersLogDateType],CAST([InvrptLogNumberofDaysToRetain] AS NVARCHAR) AS [InvrptLogNumberofDaysToRetain],
                   CAST([InvrptLogActive] AS NVARCHAR) AS [InvrptLogActive],CAST([InvrptLogStart] AS NVARCHAR) AS [InvrptLogStart],CAST([InvrptLogEnd] AS NVARCHAR) AS [InvrptLogEnd],
                   CAST([InvrptLogDateType] AS NVARCHAR) AS [InvrptLogDateType],CAST([TrigLogNumberofDaysToRetain] AS NVARCHAR) AS [TrigLogNumberofDaysToRetain],CAST([TrigLogActive] AS NVARCHAR) AS [TrigLogActive],
                   CAST([TrigLogStart] AS NVARCHAR) AS [TrigLogStart],CAST([TrigLogEnd] AS NVARCHAR) AS [TrigLogEnd],CAST([TrigLogDateType] AS NVARCHAR) AS [TrigLogDateType],
                   CAST([PTraceNumberofDaysToRetain] AS NVARCHAR) AS [PTraceNumberofDaysToRetain],CAST([PTraceActive] AS NVARCHAR) AS [PTraceActive],CAST([PTraceStart] AS NVARCHAR) AS [PTraceStart],
                   CAST([PTraceEnd] AS NVARCHAR) AS [PTraceEnd],CAST([PTraceDateType] AS NVARCHAR) AS [PTraceDateType],CAST([REPLENISHNumberofDaysToRetain] AS NVARCHAR) AS [REPLENISHNumberofDaysToRetain],
                   CAST([REPLENISHActive] AS NVARCHAR) AS [REPLENISHActive],CAST([REPLENISHStart] AS NVARCHAR) AS [REPLENISHStart],CAST([REPLENISHEnd] AS NVARCHAR) AS [REPLENISHEnd],
                   CAST([REPLENISHDateType] AS NVARCHAR) AS [REPLENISHDateType],CAST([IDActive] AS NVARCHAR) AS [IDActive],CAST([IDStart] AS NVARCHAR) AS [IDStart],CAST([IDEnd] AS NVARCHAR) AS [IDEnd],
                   CAST([InvQCNumberofDaysToRetain] AS NVARCHAR) AS [InvQCNumberofDaysToRetain],CAST([InvQCActive] AS NVARCHAR) AS [InvQCActive],CAST([InvQCStart] AS NVARCHAR) AS [InvQCStart],
                   CAST([InvQCEnd] AS NVARCHAR) AS [InvQCEnd],CAST([InvQCDateType] AS NVARCHAR) AS [InvQCDateType],CAST([InvHoldNumberofDaysToRetain] AS NVARCHAR) AS [InvHoldNumberofDaysToRetain],
                   CAST([InvHoldActive] AS NVARCHAR) AS [InvHoldActive],CAST([InvHoldStart] AS NVARCHAR) AS [InvHoldStart],CAST([InvHoldEnd] AS NVARCHAR) AS [InvHoldEnd],
                   CAST([InvHoldDateType] AS NVARCHAR) AS [InvHoldDateType],CAST([PLSNumberofDaysToRetain] AS NVARCHAR) AS [PLSNumberofDaysToRetain],CAST([PLSActive] AS NVARCHAR) AS [PLSActive],
                   CAST([PLSStart] AS NVARCHAR) AS [PLSStart],CAST([PLSEnd] AS NVARCHAR) AS [PLSEnd],CAST([PLSDateType] AS NVARCHAR) AS [PLSDateType],CAST([KITNumberofDaysToRetain] AS NVARCHAR) AS [KITNumberofDaysToRetain],
                   CAST([KITActive] AS NVARCHAR) AS [KITActive],CAST([KITStart] AS NVARCHAR) AS [KITStart],CAST([KITEnd] AS NVARCHAR) AS [KITEnd],CAST([KITDateType] AS NVARCHAR) AS [KITDateType],
                   CAST([GUINumberofDaysToRetain] AS NVARCHAR) AS [GUINumberofDaysToRetain],CAST([GUIActive] AS NVARCHAR) AS [GUIActive],CAST([GUIInvoiceNoStart] AS NVARCHAR) AS [GUIInvoiceNoStart],
                   CAST([GUIInvoiceNoEnd] AS NVARCHAR) AS [GUIInvoiceNoEnd],CAST([GUIDateType] AS NVARCHAR) AS [GUIDateType],CAST([RdsPoNumberofDaysToRetain] AS NVARCHAR) AS [RdsPoNumberofDaysToRetain],
                   CAST([RdsPodatetype] AS NVARCHAR) AS [RdsPodatetype],CAST([RdsPoActive] AS NVARCHAR) AS [RdsPoActive],CAST([RdsPoStart] AS NVARCHAR) AS [RdsPoStart],CAST([RdsPoEnd] AS NVARCHAR) AS [RdsPoEnd],
                   CAST([RdsOrdersNumberofDaysToRetain] AS NVARCHAR) AS [RdsOrdersNumberofDaysToRetain],CAST([RdsOrdersdatetype] AS NVARCHAR) AS [RdsOrdersdatetype],CAST([RdsOrdersActive] AS NVARCHAR) AS [RdsOrdersActive],
                   CAST([RdsOrdersStart] AS NVARCHAR) AS [RdsOrdersStart],CAST([RdsOrdersEnd] AS NVARCHAR) AS [RdsOrdersEnd],CAST([DailyInvNoofDaysToRetain] AS NVARCHAR) AS [DailyInvNoofDaysToRetain],
                   CAST([DailyInvActive] AS NVARCHAR) AS [DailyInvActive],CAST([DailyInvStart] AS NVARCHAR) AS [DailyInvStart],CAST([DailyInvEnd] AS NVARCHAR) AS [DailyInvEnd],
                   CAST([DailyInvDateType] AS NVARCHAR) AS [DailyInvDateType],CAST([DelPickslipNoofDaysToRetain] AS NVARCHAR) AS [DelPickslipNoofDaysToRetain],CAST([DelPickslipActive] AS NVARCHAR) AS [DelPickslipActive],
                   CAST([DelPickslipStart] AS NVARCHAR) AS [DelPickslipStart],CAST([DelPickslipEnd] AS NVARCHAR) AS [DelPickslipEnd],CAST([DelPickslipDateType] AS NVARCHAR) AS [DelPickslipDateType],
                   CAST([SMSPODNumberofDaysToRetain] AS NVARCHAR) AS [SMSPODNumberofDaysToRetain],CAST([SMSPODActive] AS NVARCHAR) AS [SMSPODActive],CAST([SMSPODDateType] AS NVARCHAR) AS [SMSPODDateType]  
                   FROM INSERTED WITH (NOLOCK)) pvt
            UNPIVOT
            (
               NewValue FOR [Column]  IN 
               (  [CopyRowsToArchiveDatabase],[ArchiveDataBaseName],[LiveDataBaseName],[ShipNumberofDaysToRetain],[ShipActive],[ShipStorerKeyStart],[ShipStorerKeyEnd],  
                  [ShipSysOrdStart],[ShipSysOrdEnd],[ShipExternOrderKeyStart],[ShipExternOrderKeyEnd],[ShipOrdTypStart],[ShipOrdTypEnd],[ShipOrdGrpStart],[ShipOrdGrpEnd],
                  [ShipToStart],[ShipToEnd], [ShipBillToStart],[ShipBillToEnd],[ShipmentOrderDateType],[AdjNumberofDaysToRetain],[AdjActive],[AdjStart],[AdjEnd],[AdjustmentDateType],
                  [TranNumberofDaysToRetain],[TranActive],[TranStart],[TranEnd],[TransferDateType],  
                  [PONumberofDaysToRetain],[POActive],[POStorerKeyStart],[POStorerKeyEnd],[POStart],[POEnd],[PODateType],  
                  [ReceiptNumberofDaysToRetain],[ReceiptActive],[ReceiptStorerKeyStart],[ReceiptStorerKeyEnd],[ReceiptStart],[ReceiptEnd],[ReceiptDateType],  
                  [ItrnNumberofDaysToRetain],[ItrnActive],[ItrnStorerKeyStart],[ItrnStorerKeyEnd],[ItrnSkuStart],[ItrnSkuEnd],[ItrnLotStart],[ItrnLotEnd],[ItrnDateType],  
                  [MAWBNumberofDaysToRetain],[MAWBActive],[MAWBStart],[MAWBEnd],[MAWBDateType],[HAWBNumberofDaysToRetain],[HAWBActive],[HAWBStart],[HAWBEnd],[HAWBDateType],  
                  [ContainerNumberofDaysToRetain],[ContainerActive],[ContainerStart],[ContainerEnd],[ContainerDateType],
                  [PalletNumberofDaysToRetain],[PalletActive],[PalletStart],[PalletEnd],[PalletDateType],
                  [CaseMNumberofDaysToRetain],[CaseMActive],[CaseMStorerKeyStart],[CaseMStorerKeyEnd],[CaseMStart],[CaseMEnd],[CaseMDateType],
                  [MbolNumberofDaysToRetain],[MbolActive],[MbolStart],[MbolEnd],[MBOLDepDateStart],[MBOLDepDateEnd],[MBOLDelDateStart],[MBOLDelDateEnd],[MbolVoyageStart],[MbolVoyageEnd],
                  [MBOLDateType],[PickDateType] /*,[AddDate],[AddWho],[EditDate],[EditWho]*/,[TrafficCop],[ArchiveCop],  
                  [CCNumberofDaysToRetain],[CCActive],[CCStart],[CCEnd],[CCDateType],  
                  [AlertNumberofDaysToRetain],[AlertActive],[AlertStart],[AlertEnd],[AlertDateType], [RFDBLogNumberofDaysToRetain],[RFDBLogActive],[RFDBLogDateType],  
                  [SKULogNumberofDaysToRetain],[SKULogActive],[SKULogDateType],[ErrLogNumberofDaysToRetain],[ErrLogActive],[ErrLogDateType],  
                  [PackLogNumberofDaysToRetain],[PackLogActive],[PackLogStart],[PackLogEnd],[PackLogDateType],  
                  [TranmLogNumberofDaysToRetain],[TranmLogActive],[TranmLogStart],[TranmLogEnd],[TranmLogDateType],  
                  [OrdersLogNumberofDaysToRetain],[OrdersLogActive],[OrdersLogStart],[OrdersLogEnd],[OrdersLogDateType],  
                  [InvrptLogNumberofDaysToRetain],[InvrptLogActive],[InvrptLogStart],[InvrptLogEnd],[InvrptLogDateType],  
                  [TrigLogNumberofDaysToRetain],[TrigLogActive],[TrigLogStart],[TrigLogEnd],[TrigLogDateType],  
                  [PTraceNumberofDaysToRetain],[PTraceActive],[PTraceStart],[PTraceEnd],[PTraceDateType],  
                  [REPLENISHNumberofDaysToRetain],[REPLENISHActive],[REPLENISHStart],[REPLENISHEnd],[REPLENISHDateType],  
                  [IDActive],[IDStart],[IDEnd],[InvQCNumberofDaysToRetain],[InvQCActive],[InvQCStart],[InvQCEnd],[InvQCDateType],[InvHoldNumberofDaysToRetain],[InvHoldActive],
                  [InvHoldStart],[InvHoldEnd],[InvHoldDateType],  
                  [PLSNumberofDaysToRetain],[PLSActive],[PLSStart],[PLSEnd],[PLSDateType],  
                  [KITNumberofDaysToRetain],[KITActive],[KITStart],[KITEnd],[KITDateType],  
                  [GUINumberofDaysToRetain],[GUIActive],[GUIInvoiceNoStart],[GUIInvoiceNoEnd],[GUIDateType],  
                  [RdsPoNumberofDaysToRetain],[RdsPodatetype],[RdsPoActive],[RdsPoStart],[RdsPoEnd],[RdsOrdersNumberofDaysToRetain],[RdsOrdersdatetype],[RdsOrdersActive],
                  [RdsOrdersStart],[RdsOrdersEnd],  
                  [DailyInvNoofDaysToRetain],[DailyInvActive],[DailyInvStart],[DailyInvEnd],[DailyInvDateType],[DelPickslipNoofDaysToRetain],[DelPickslipActive],[DelPickslipStart],
                  [DelPickslipEnd],[DelPickslipDateType],  
                  [SMSPODNumberofDaysToRetain],[SMSPODActive],[SMSPODDateType] 
               )             
            ) AS unpvt 
      
      DECLARE CUR_ITEM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT INS.ArchiveKey, INS.[Column], DEL.[OldValue], INS.[NewValue]
      FROM #INSERTED INS WITH (NOLOCK)
      LEFT JOIN #DELETED DEL WITH (NOLOCK) ON INS.Archivekey = DEL.Archivekey AND INS.[Column] = DEL.[Column]
      WHERE  INS.NewValue  <> DEL.OldValue

      OPEN CUR_ITEM
      FETCH NEXT FROM CUR_ITEM INTO @c_ArchiveKey, @c_Column, @c_OldValue, @c_NewValue
      WHILE @@FETCH_STATUS = 0
      BEGIN
       BEGIN TRY
         INSERT [dbo].[ARCHIVEPARAMETERS_LOG] ([ArchiveKey], [FieldName], [OldValue], [NewValue]) 
         SELECT @c_ArchiveKey, @c_Column, @c_OldValue, @c_NewValue
       END TRY
       BEGIN CATCH
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62304   -- Should Be Set To The SQL Err message but I don't know how to do so.  
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": INSERT Failed on ARCHIVEPARAMETERS_LOG table. (ntrARCHIVEPARAMETERSUpdate)"   
                        + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "  
       END CATCH

      FETCH NEXT FROM CUR_ITEM INTO @c_ArchiveKey, @c_Column, @c_OldValue, @c_NewValue
      END
      CLOSE CUR_ITEM
      DEALLOCATE CUR_ITEM

   END

   IF UPDATE(TrafficCop)  
   BEGIN  
      SELECT @n_continue = 4   
   END 
        
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      execute nsp_logerror @n_err, @c_errmsg, "ntrARCHIVEPARAMETERSUpdate"  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  
  
END  

GO