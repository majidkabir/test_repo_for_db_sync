SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE   PROCEDURE [dbo].[isp_AlertNonExceedTable]   
   @cOperator     NVARCHAR(215) = '',  
   @cRecipients   NVARCHAR(215) = ''  
AS   
  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
DECLARE @csubject  NVARCHAR(256),  
        @cemail_address NVARCHAR(max)  

Set @csubject = 'Alert - NON-EXceed Table in WMS DB Notification from ' + @@servername  
Set @cRecipients = ISNULL(RTRIM(@cRecipients), '')  
 
IF ISNULL(RTRIM(@cOperator), '') <> ''           
BEGIN  
   Set @cemail_address = ''     
   Select @cemail_address = ISNULL(RTRIM(email_address), '')    
   FROM msdb.dbo.sysoperators  
   WHERE enabled = '1'  
   AND  name = ISNULL(RTRIM(@cOperator), '')  
     
   IF ISNULL(RTRIM(@cemail_address), '') <> ''  
   BEGIN  
      IF Left(@cemail_address, 1) <> ';'  
      BEGIN  
         SET @cemail_address = @cemail_address + ';'  
      END  
        
      Select @cRecipients = @cemail_address + @cRecipients  
   END   
END  

IF OBJECT_ID('tempdb..#NonStandardTable') IS NOT NULL
   DROP TABLE #NonStandardTable
   
Create Table #NonStandardTable
(TableName   NVARCHAR(40),
 CreateDate  datetime )

IF OBJECT_ID('tempdb..#StandardTable') IS NOT NULL
   DROP TABLE #NonStandardTable
CREATE TABLE #StandardTable (TableName NVARCHAR(60))

   INSERT INTO #StandardTable( TableName) VALUES ('REPLENISHMENT_LOCK')
   INSERT INTO #StandardTable( TableName) VALUES ('BATCHPICK')
   INSERT INTO #StandardTable( TableName) VALUES ('vasdetail')
   INSERT INTO #StandardTable( TableName) VALUES ('RFDB_LOG')
   INSERT INTO #StandardTable( TableName) VALUES ('Blocking_sysprocesses')
   INSERT INTO #StandardTable( TableName) VALUES ('BILLING_DETAIL_CUT')
   INSERT INTO #StandardTable( TableName) VALUES ('WMSFieldsList')
   INSERT INTO #StandardTable( TableName) VALUES ('RFPUTAWAY')
   INSERT INTO #StandardTable( TableName) VALUES ('BILLING_SUMMARY_CUT')
   INSERT INTO #StandardTable( TableName) VALUES ('rdsOrderDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('RouteMaster')
   INSERT INTO #StandardTable( TableName) VALUES ('BILL_ACCUMULATEDCHARGES')
   INSERT INTO #StandardTable( TableName) VALUES ('RunNo')
   INSERT INTO #StandardTable( TableName) VALUES ('BILL_STOCKMOVEMENT')
   INSERT INTO #StandardTable( TableName) VALUES ('SKU')
   INSERT INTO #StandardTable( TableName) VALUES ('BILL_STOCKMOVEMENT_DETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('SKUConfig')
   INSERT INTO #StandardTable( TableName) VALUES ('BOL')
   INSERT INTO #StandardTable( TableName) VALUES ('GUI')
   INSERT INTO #StandardTable( TableName) VALUES ('SKULog')
   INSERT INTO #StandardTable( TableName) VALUES ('UCC')
   INSERT INTO #StandardTable( TableName) VALUES ('idsMoveStock')
   INSERT INTO #StandardTable( TableName) VALUES ('BOLDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('SKUxLOC')
   INSERT INTO #StandardTable( TableName) VALUES ('C4_Rec_Exp')
   INSERT INTO #StandardTable( TableName) VALUES ('CALENDAR')
   INSERT INTO #StandardTable( TableName) VALUES ('OrderSelection')
   INSERT INTO #StandardTable( TableName) VALUES ('STORERBILLING')
   INSERT INTO #StandardTable( TableName) VALUES ('CALENDARDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('Section')
   INSERT INTO #StandardTable( TableName) VALUES ('Indexes')
   INSERT INTO #StandardTable( TableName) VALUES ('CARTONIZATION')
   INSERT INTO #StandardTable( TableName) VALUES ('CASEMANIFEST')
   INSERT INTO #StandardTable( TableName) VALUES ('Services')
   INSERT INTO #StandardTable( TableName) VALUES ('ORDERCONF')
   INSERT INTO #StandardTable( TableName) VALUES ('CC')
   INSERT INTO #StandardTable( TableName) VALUES ('nCounterNSC')
   INSERT INTO #StandardTable( TableName) VALUES ('WMSEXPMBOL')
   INSERT INTO #StandardTable( TableName) VALUES ('CCDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('rdsOrderDetailSize')
   --INSERT INTO #StandardTable( TableName) VALUES ('WMSSKU')
   INSERT INTO #StandardTable( TableName) VALUES ('CC_Error')
   INSERT INTO #StandardTable( TableName) VALUES ('PODETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('StorerSODefault')
   INSERT INTO #StandardTable( TableName) VALUES ('CLPDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('Holiday')
   INSERT INTO #StandardTable( TableName) VALUES ('Strategy')
   INSERT INTO #StandardTable( TableName) VALUES ('NSCLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('CLPORDER')
   INSERT INTO #StandardTable( TableName) VALUES ('TARIFFxFACILITY')
   INSERT INTO #StandardTable( TableName) VALUES ('CODELIST')
   INSERT INTO #StandardTable( TableName) VALUES ('OWOrdAlloc')
   INSERT INTO #StandardTable( TableName) VALUES ('TRANSFER')
   INSERT INTO #StandardTable( TableName) VALUES ('WorkOrder')
   INSERT INTO #StandardTable( TableName) VALUES ('CODELKUP')
   INSERT INTO #StandardTable( TableName) VALUES ('TRANSFERDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('WorkOrderDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('CONTAINER')
   INSERT INTO #StandardTable( TableName) VALUES ('rdsGrantedStorer')
   INSERT INTO #StandardTable( TableName) VALUES ('TRANSMITLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('CONTAINERDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('TRIDENTC4LGTH')
   INSERT INTO #StandardTable( TableName) VALUES ('ChartOfAccounts')
   INSERT INTO #StandardTable( TableName) VALUES ('TRIDENTSCHEDULER')
   INSERT INTO #StandardTable( TableName) VALUES ('ContainerBilling')
   INSERT INTO #StandardTable( TableName) VALUES ('TTMStrategy')
   INSERT INTO #StandardTable( TableName) VALUES ('ControlTable')
   INSERT INTO #StandardTable( TableName) VALUES ('WMS_Blocking')
   INSERT INTO #StandardTable( TableName) VALUES ('GUIDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('TTMStrategyDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('WMS_Trace')
   INSERT INTO #StandardTable( TableName) VALUES ('Tariff')
   INSERT INTO #StandardTable( TableName) VALUES ('Dropid')
   INSERT INTO #StandardTable( TableName) VALUES ('POD')
   INSERT INTO #StandardTable( TableName) VALUES ('WMS_Process')
   INSERT INTO #StandardTable( TableName) VALUES ('TariffDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('DropidDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('TaskDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('ERRLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('rdsRole')
   INSERT INTO #StandardTable( TableName) VALUES ('PICKORDERLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('TaskManagerReason')
   INSERT INTO #StandardTable( TableName) VALUES ('EquipmentProfile')
   INSERT INTO #StandardTable( TableName) VALUES ('TaskManagerSkipTasks')
   INSERT INTO #StandardTable( TableName) VALUES ('Exe2OW_AllocPickShip')
   INSERT INTO #StandardTable( TableName) VALUES ('TaskManagerUser')
   INSERT INTO #StandardTable( TableName) VALUES ('FACILITY')
   INSERT INTO #StandardTable( TableName) VALUES ('TaskManagerUserDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('ids_inventory_balance')
   INSERT INTO #StandardTable( TableName) VALUES ('FxRATE')
   INSERT INTO #StandardTable( TableName) VALUES ('rdsMenu')
   INSERT INTO #StandardTable( TableName) VALUES ('TaxGroup')
   INSERT INTO #StandardTable( TableName) VALUES ('GLDistribution')
   INSERT INTO #StandardTable( TableName) VALUES ('TaxGroupDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('GLDistributionDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('TaxRate')
   INSERT INTO #StandardTable( TableName) VALUES ('HIERROR')
   INSERT INTO #StandardTable( TableName) VALUES ('STORER')
   INSERT INTO #StandardTable( TableName) VALUES ('TempMoveSku')
   INSERT INTO #StandardTable( TableName) VALUES ('HOSTINTERFACE')
   INSERT INTO #StandardTable( TableName) VALUES ('TempPickSlip')
   INSERT INTO #StandardTable( TableName) VALUES ('HOUSEAIRWAYBILL')
   INSERT INTO #StandardTable( TableName) VALUES ('StockTakeSheetParameters')
   INSERT INTO #StandardTable( TableName) VALUES ('HOUSEAIRWAYBILLDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('rdsUser')
   INSERT INTO #StandardTable( TableName) VALUES ('rdsPO')
   INSERT INTO #StandardTable( TableName) VALUES ('ID')
   INSERT INTO #StandardTable( TableName) VALUES ('ARCHIVEPARAMETERS')
   INSERT INTO #StandardTable( TableName) VALUES ('IDSCNDailyInventory')
   INSERT INTO #StandardTable( TableName) VALUES ('DailyInventory')
   INSERT INTO #StandardTable( TableName) VALUES ('UPLOADORDERDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('IDS_CONSIGNEE_THAI')
   INSERT INTO #StandardTable( TableName) VALUES ('rdsPODetail')
   INSERT INTO #StandardTable( TableName) VALUES ('UPLOADORDERHEADER')
   INSERT INTO #StandardTable( TableName) VALUES ('IDS_LP_Driver')
   INSERT INTO #StandardTable( TableName) VALUES ('dtproperties')
   INSERT INTO #StandardTable( TableName) VALUES ('UPLOADPOHeader')
   INSERT INTO #StandardTable( TableName) VALUES ('IDS_LP_VEHICLE')
   INSERT INTO #StandardTable( TableName) VALUES ('PackInfo')
   INSERT INTO #StandardTable( TableName) VALUES ('IDS_VEHICLE')
   INSERT INTO #StandardTable( TableName) VALUES ('UploadINVBAL')
   INSERT INTO #StandardTable( TableName) VALUES ('INVENTORYHOLD')
   INSERT INTO #StandardTable( TableName) VALUES ('UploadPODetail')
   INSERT INTO #StandardTable( TableName) VALUES ('ITRN')
   INSERT INTO #StandardTable( TableName) VALUES ('DEL_ORDERDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('UploadinvData')
   INSERT INTO #StandardTable( TableName) VALUES ('ITRNHDR')
   INSERT INTO #StandardTable( TableName) VALUES ('PO') 
   INSERT INTO #StandardTable( TableName) VALUES ('WAVE')
   INSERT INTO #StandardTable( TableName) VALUES ('idsPallet')
   INSERT INTO #StandardTable( TableName) VALUES ('InvRptLog')
   INSERT INTO #StandardTable( TableName) VALUES ('WAVEDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('TMSLog')
   INSERT INTO #StandardTable( TableName) VALUES ('InventoryQC')
   --INSERT INTO #StandardTable( TableName) VALUES ('WMSEXPADJ')
   INSERT INTO #StandardTable( TableName) VALUES ('InventoryQCDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('IDSAllocationPool')
   INSERT INTO #StandardTable( TableName) VALUES ('SerialNo')
   --INSERT INTO #StandardTable( TableName) VALUES ('WMSEXPASN')
   INSERT INTO #StandardTable( TableName) VALUES ('KIT')
   --INSERT INTO #StandardTable( TableName) VALUES ('WMSEXPINVHOLD')
   INSERT INTO #StandardTable( TableName) VALUES ('KITDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('nCounterTrigantic')
   --INSERT INTO #StandardTable( TableName) VALUES ('WMSEXPKIT')
   INSERT INTO #StandardTable( TableName) VALUES ('LABELLIST')
   INSERT INTO #StandardTable( TableName) VALUES ('RECEIPTDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('LOC')
   INSERT INTO #StandardTable( TableName) VALUES ('WMSEXPMBOLBK')
   INSERT INTO #StandardTable( TableName) VALUES ('LOT')
   --INSERT INTO #StandardTable( TableName) VALUES ('WMSEXPMOVE')
   INSERT INTO #StandardTable( TableName) VALUES ('LOTATTRIBUTE')
   INSERT INTO #StandardTable( TableName) VALUES ('XDOCKStrategy')
   --INSERT INTO #StandardTable( TableName) VALUES ('WMSEXPSOH')
   INSERT INTO #StandardTable( TableName) VALUES ('LOTNEWBILLTHRUDATE')
   --INSERT INTO #StandardTable( TableName) VALUES ('WMSEXPTRF')
   INSERT INTO #StandardTable( TableName) VALUES ('RDSSize')
   INSERT INTO #StandardTable( TableName) VALUES ('LOTxBILLDATE')
   INSERT INTO #StandardTable( TableName) VALUES ('TRIGANTICLOG')
   --INSERT INTO #StandardTable( TableName) VALUES ('WMSORD')
   INSERT INTO #StandardTable( TableName) VALUES ('LOTxLOCxID')
   INSERT INTO #StandardTable( TableName) VALUES ('DOCLKUP')
   INSERT INTO #StandardTable( TableName) VALUES ('WMSORM') 
   INSERT INTO #StandardTable( TableName) VALUES ('WMSPAK')
   --INSERT INTO #StandardTable( TableName) VALUES ('WMSRCD')
   INSERT INTO #StandardTable( TableName) VALUES ('idsStkTrfDoc')
   INSERT INTO #StandardTable( TableName) VALUES ('SKU2')
   INSERT INTO #StandardTable( TableName) VALUES ('LoadPlanRetDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('WMSRCM')
   INSERT INTO #StandardTable( TableName) VALUES ('ConsigneeSKU')
   INSERT INTO #StandardTable( TableName) VALUES ('RDSSizeDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('OriginAllocQty')
   INSERT INTO #StandardTable( TableName) VALUES ('LotxIdDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('MASTERAIRWAYBILL')
   INSERT INTO #StandardTable( TableName) VALUES ('MASTERAIRWAYBILLDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('TraceInfo')
   INSERT INTO #StandardTable( TableName) VALUES ('XDOCK')
   INSERT INTO #StandardTable( TableName) VALUES ('idsStkTrfDocDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('MBOL')
   INSERT INTO #StandardTable( TableName) VALUES ('XDOCKDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('MBOLDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('PackDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('help')
   INSERT INTO #StandardTable( TableName) VALUES ('ORDERS')
   INSERT INTO #StandardTable( TableName) VALUES ('MESSAGE_ID')
   INSERT INTO #StandardTable( TableName) VALUES ('RDSStyle')
   INSERT INTO #StandardTable( TableName) VALUES ('stocktakeparm2')
   INSERT INTO #StandardTable( TableName) VALUES ('MESSAGE_TEXT')
   INSERT INTO #StandardTable( TableName) VALUES ('rdsORDERS')
   INSERT INTO #StandardTable( TableName) VALUES ('ORDERS_ALERT')
   INSERT INTO #StandardTable( TableName) VALUES ('NCOUNTER')
   INSERT INTO #StandardTable( TableName) VALUES ('BillOfMaterial')
   INSERT INTO #StandardTable( TableName) VALUES ('NCOUNTERITRN')
   INSERT INTO #StandardTable( TableName) VALUES ('NCOUNTERPICK')
   INSERT INTO #StandardTable( TableName) VALUES ('UPLOADC4ORDERDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('ids_label_count')
   INSERT INTO #StandardTable( TableName) VALUES ('NCOUNTERTRACE')
   INSERT INTO #StandardTable( TableName) VALUES ('UPLOADC4ORDERHEADER')
   INSERT INTO #StandardTable( TableName) VALUES ('ids_lp_nested_orderkey')
   INSERT INTO #StandardTable( TableName) VALUES ('NSQLCONFIG')
   INSERT INTO #StandardTable( TableName) VALUES ('ORDERS_STATUS')
   INSERT INTO #StandardTable( TableName) VALUES ('OP_CARTONLINES')
   INSERT INTO #StandardTable( TableName) VALUES ('ids_ec_scgdsrn')
   INSERT INTO #StandardTable( TableName) VALUES ('RDSStyleColor')
   INSERT INTO #StandardTable( TableName) VALUES ('pbcatcol')
   INSERT INTO #StandardTable( TableName) VALUES ('ORDERDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('ORDERinfo')
   INSERT INTO #StandardTable( TableName) VALUES ('pbcatedt')
   INSERT INTO #StandardTable( TableName) VALUES ('pbcatfmt')
   INSERT INTO #StandardTable( TableName) VALUES ('RCMReport')
   INSERT INTO #StandardTable( TableName) VALUES ('pbcattbl')
   INSERT INTO #StandardTable( TableName) VALUES ('pbcatvld')
   INSERT INTO #StandardTable( TableName) VALUES ('ORDERS_TACTIVITY')
   INSERT INTO #StandardTable( TableName) VALUES ('OrderScan')
   INSERT INTO #StandardTable( TableName) VALUES ('pbsrpt_category')
   INSERT INTO #StandardTable( TableName) VALUES ('pbsrpt_parms')
   INSERT INTO #StandardTable( TableName) VALUES ('PACK')
   INSERT INTO #StandardTable( TableName) VALUES ('RDSStyleColorSize')
   INSERT INTO #StandardTable( TableName) VALUES ('pbsrpt_reports')
   INSERT INTO #StandardTable( TableName) VALUES ('PACKLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('pbsrpt_set_reports')
   INSERT INTO #StandardTable( TableName) VALUES ('PALLET')
   INSERT INTO #StandardTable( TableName) VALUES ('pbsrpt_sets')
   INSERT INTO #StandardTable( TableName) VALUES ('ORDERS_TADDED')
   INSERT INTO #StandardTable( TableName) VALUES ('PALLETDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('UPLOADC4POHeader')
   INSERT INTO #StandardTable( TableName) VALUES ('LoadPlan')
   INSERT INTO #StandardTable( TableName) VALUES ('PAZoneEquipmentExcludeDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('UploadC4PODetail')
   
   INSERT INTO #StandardTable( TableName) VALUES ('PHYSICAL')
   INSERT INTO #StandardTable( TableName) VALUES ('PHY_A2B_ID')
   INSERT INTO #StandardTable( TableName) VALUES ('PHY_A2B_LOT')
   INSERT INTO #StandardTable( TableName) VALUES ('sysdiagrams')
   INSERT INTO #StandardTable( TableName) VALUES ('PHY_A2B_SKU')
   INSERT INTO #StandardTable( TableName) VALUES ('PHY_A2B_TAG')
   INSERT INTO #StandardTable( TableName) VALUES ('PHY_INV2A_ID')
   INSERT INTO #StandardTable( TableName) VALUES ('RDSColor')
   INSERT INTO #StandardTable( TableName) VALUES ('PHY_INV2A_LOT')
   INSERT INTO #StandardTable( TableName) VALUES ('PHY_INV2A_SKU')
   INSERT INTO #StandardTable( TableName) VALUES ('PHY_POSTED')
   INSERT INTO #StandardTable( TableName) VALUES ('PHY_POST_DETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('PHY_missing_tag_a')
   INSERT INTO #StandardTable( TableName) VALUES ('PHY_missing_tag_b')
   INSERT INTO #StandardTable( TableName) VALUES ('RDSColorDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('PHY_outofrange_tag_a')
   INSERT INTO #StandardTable( TableName) VALUES ('VITALLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('StorerConfig')
   INSERT INTO #StandardTable( TableName) VALUES ('PHY_outofrange_tag_b')
   INSERT INTO #StandardTable( TableName) VALUES ('PICKDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('DEL_ORDERS')
   INSERT INTO #StandardTable( TableName) VALUES ('PICKHEADER')
   INSERT INTO #StandardTable( TableName) VALUES ('DEL_PICKDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('POLL_ALLOCATE')
   INSERT INTO #StandardTable( TableName) VALUES ('POLL_PICK')
   INSERT INTO #StandardTable( TableName) VALUES ('UPC')
   INSERT INTO #StandardTable( TableName) VALUES ('MBOLShipLog')
   INSERT INTO #StandardTable( TableName) VALUES ('POLL_PRINT')
   INSERT INTO #StandardTable( TableName) VALUES ('POLL_SHIP')
   INSERT INTO #StandardTable( TableName) VALUES ('ls_storerkey')
   INSERT INTO #StandardTable( TableName) VALUES ('POLL_UPDATE')
   INSERT INTO #StandardTable( TableName) VALUES ('TempStkVar')
   INSERT INTO #StandardTable( TableName) VALUES ('PTRACEDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('PTRACEHEAD')
   INSERT INTO #StandardTable( TableName) VALUES ('tbl')
   INSERT INTO #StandardTable( TableName) VALUES ('rdsPODetailSize')
   INSERT INTO #StandardTable( TableName) VALUES ('TBLSKU')
   INSERT INTO #StandardTable( TableName) VALUES ('InvHoldSkuLog')
   INSERT INTO #StandardTable( TableName) VALUES ('PackHeader')
   INSERT INTO #StandardTable( TableName) VALUES ('HolidayDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('VASDetail_bak')
   INSERT INTO #StandardTable( TableName) VALUES ('PalletMaster')
   INSERT INTO #StandardTable( TableName) VALUES ('HolidayHeader')
   INSERT INTO #StandardTable( TableName) VALUES ('PhysicalParameters')
   INSERT INTO #StandardTable( TableName) VALUES ('PickingInfo')
   INSERT INTO #StandardTable( TableName) VALUES ('PreAllocatePickDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('PreAllocateStrategy')
   INSERT INTO #StandardTable( TableName) VALUES ('InterfaceLog')
   INSERT INTO #StandardTable( TableName) VALUES ('ACCUMULATEDCHARGES')
   INSERT INTO #StandardTable( TableName) VALUES ('TRANSMITLOG2')
   INSERT INTO #StandardTable( TableName) VALUES ('LoadPlanDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('PreAllocateStrategyDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('ADJUSTMENT')
   INSERT INTO #StandardTable( TableName) VALUES ('UPLOADTHPODETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('PutawayStrategy')
   INSERT INTO #StandardTable( TableName) VALUES ('ADJUSTMENTDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('UPLOADTHPOHEADER')
   INSERT INTO #StandardTable( TableName) VALUES ('PutawayStrategyDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('ALERT')
   INSERT INTO #StandardTable( TableName) VALUES ('PutawayTask') 
   INSERT INTO #StandardTable( TableName) VALUES ('InvHoldTransLog')
   INSERT INTO #StandardTable( TableName) VALUES ('TempStock')
   INSERT INTO #StandardTable( TableName) VALUES ('UCCCounter')
   INSERT INTO #StandardTable( TableName) VALUES ('PutawayZone')
   INSERT INTO #StandardTable( TableName) VALUES ('TRANSMITLOG3')
   INSERT INTO #StandardTable( TableName) VALUES ('Accessorial')
   INSERT INTO #StandardTable( TableName) VALUES ('AccessorialDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('orderslog')
   INSERT INTO #StandardTable( TableName) VALUES ('RECEIPT')
   INSERT INTO #StandardTable( TableName) VALUES ('TriganticCC')
   INSERT INTO #StandardTable( TableName) VALUES ('AllocateStrategy')
   INSERT INTO #StandardTable( TableName) VALUES ('WithdrawStock')
   INSERT INTO #StandardTable( TableName) VALUES ('RefKeyLookup')
   INSERT INTO #StandardTable( TableName) VALUES ('AllocateStrategyDetail') 
   INSERT INTO #StandardTable( TableName) VALUES ('REPLENISHMENT')
   INSERT INTO #StandardTable( TableName) VALUES ('RECUPLOAD')
   INSERT INTO #StandardTable( TableName) VALUES ('ApptId')
   INSERT INTO #StandardTable( TableName) VALUES ('AreaDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('WaveOrderLn')
   INSERT INTO #StandardTable( TableName) VALUES ('LOCBak')
   INSERT INTO #StandardTable( TableName) VALUES ('UnauthorizeAccess')
   INSERT INTO #StandardTable( TableName) VALUES ('User_Connections')
   INSERT INTO #StandardTable( TableName) VALUES ('InterfaceParmLog')
   INSERT INTO #StandardTable( TableName) VALUES ('DailyInventoryNW')
   INSERT INTO #StandardTable( TableName) VALUES ('TmpAlloc_vs_PPA_VarReport')
   INSERT INTO #StandardTable( TableName) VALUES ('IDS_DWGRIDPOS')
   INSERT INTO #StandardTable( TableName) VALUES ('IDS_FavoriteMenu')
   INSERT INTO #StandardTable( TableName) VALUES ('IDS_GeneralLog')
   INSERT INTO #StandardTable( TableName) VALUES ('CMSLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('OWRCPTTrace')  	-- TP
   INSERT INTO #StandardTable( TableName) VALUES ('PDA_PnP_Trace')	-- HK
   INSERT INTO #StandardTable( TableName) VALUES ('DEL_PICKORDERLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('TmpShip') -- TH
   INSERT INTO #StandardTable( TableName) VALUES ('TmpLdSm_VarReport') -- TH
   INSERT INTO #StandardTable( TableName) VALUES ('TmpPPA')	-- TH
   INSERT INTO #StandardTable( TableName) VALUES ('XDPARTIALPLT') 	-- TH
   INSERT INTO #StandardTable( TableName) VALUES ('InvBalIntegrityTrace') -- PH
   INSERT INTO #StandardTable( TableName) VALUES ('HoldStock')
   INSERT INTO #StandardTable( TableName) VALUES ('Pickdet_log') -- US
   INSERT INTO #StandardTable( TableName) VALUES ('IDS_GSISpooler') -- US
   
   INSERT INTO #StandardTable( TableName) VALUES ('PackDetail_RDT') -- UK
   INSERT INTO #StandardTable( TableName) VALUES ('rdtBOMCreationLog') -- RDT
   INSERT INTO #StandardTable( TableName) VALUES ('DEL_CCDetail') -- TW
   INSERT INTO #StandardTable( TableName) VALUES ('RDTCCLock')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTCfg_SYS')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTCfg_User')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtCSAudit')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtCSAudit_Batch')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTCSAudit_BatchPO')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtCSAudit_Load')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtDataCapture')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtDynamicPickLog')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTEventLog')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTEventLogDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtFlowThruSort')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtFlowThruSortDistr')
   INSERT INTO #StandardTable( TableName) VALUES ('RdtGOHSettagelog')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTGSICartonLabel_XML')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTMenu')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTMESSAGE')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTMOBREC')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTMsg')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtMsgQueue')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtPickLock')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTPPA')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTPrinter')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTPrintJob')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtProgramRights')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTReport')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtScanToTruck')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTSchedule')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTScn')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTSCNDETAIL')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTSCNHeader')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTSessionData')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtSTDEventLog')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTTempUCC')
   INSERT INTO #StandardTable( TableName) VALUES ('rdttest')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtToteInfoLog')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTTRace')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtTraceSummary')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTUCC')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTUser')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtVASLog')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtWATLog')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTXML')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTXML_Elm')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTXML_Root') -- RDT
   INSERT INTO #StandardTable( TableName) VALUES ('SKU_LOG') -- IDSPH
   INSERT INTO #StandardTable( TableName) VALUES ('LoadPlanLaneDetail') -- US
   INSERT INTO #StandardTable( TableName) VALUES ('RDTMESSAGE')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtTaskManagerConfig')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtTMLog')
   INSERT INTO #StandardTable( TableName) VALUES ('SwapUCC')
   INSERT INTO #StandardTable( TableName) VALUES ('TraceTM')
   INSERT INTO #StandardTable( TableName) VALUES ('CartonTrack') 	-- CN Carter
   INSERT INTO #StandardTable( TableName) VALUES ('TableDeleteLog')
   INSERT INTO #StandardTable( TableName) VALUES ('AllocShortageLog') -- US
   INSERT INTO #StandardTable( TableName) VALUES ('SKUxLOCIntegrity')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtDPKLog') -- UK Diana
   INSERT INTO #StandardTable( TableName) VALUES ('rdtECOMMLog')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtPutawayLog')
   INSERT INTO #StandardTable( TableName) VALUES ('SHIFT')
   INSERT INTO #StandardTable( TableName) VALUES ('StoreToLocDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('WCSRouting')
   INSERT INTO #StandardTable( TableName) VALUES ('WCSRoutingDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('WCSSTATIONRESPONSE') -- UK Diana
   INSERT INTO #StandardTable( TableName) VALUES ('USPSAddress') -- US
   INSERT INTO #StandardTable( TableName) VALUES ('GS1Log') --US
   INSERT INTO #StandardTable( TableName) VALUES ('TM_PickLog') --US
   INSERT INTO #StandardTable( TableName) VALUES ('rdtPackLog')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtQCInquiryLog') -- Diana
   INSERT INTO #StandardTable( TableName) VALUES ('StorerSODefaultDate') -- CN
   INSERT INTO #StandardTable( TableName) VALUES ('PICKORDERLOG_ADD') -- HK08
   INSERT INTO #StandardTable( TableName) VALUES ('rdtDPKLog_BAK') --UK
   INSERT INTO #StandardTable( TableName) VALUES ('WITRONLOG') -- SG
   INSERT INTO #StandardTable( TableName) VALUES ('rdtPickLog')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtTrackLog') -- CN
   INSERT INTO #StandardTable( TableName) VALUES ('StockTakeEntryLog') 	-- MY Stocktake
   INSERT INTO #StandardTable( TableName) VALUES ('WMS_SysProcess')
   INSERT INTO #StandardTable( TableName) VALUES ('UPC_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('ADJUSTMENT_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('ADJUSTMENTDETAIL_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('BillOfMaterial_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('CODELKUP_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('FACILITY_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('INVENTORYHOLD_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('InventoryQC_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('InventoryQCDetail_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('KIT_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('KITDETAIL_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('LOC_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('ORDERDETAIL_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('ORDERS_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('PACK_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('PackDetail_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('PICKHEADER_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('PickingInfo_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('PO_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('PODETAIL_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('PutawayZone_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('RECEIPT_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('RECEIPTDETAIL_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('RefKeyLookup_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('REPLENISHMENT_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('SKU_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('SKUxLOC_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('STORER_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('TRANSFER_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('TRANSFERDETAIL_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('UCC_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('UPC_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('WorkOrder_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('WorkOrderDetail_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('CCDetail_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('LoadPlan_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('LoadPlanDetail_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('MBOL_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('MBOLDETAIL_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('PackHeader_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('PackInfo_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('PICKDETAIL_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('POD_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('rdsOrderDetail_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('rdsOrderDetailSize_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('rdsORDERS_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('rdsPO_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('rdsPODetail_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('rdsPODetailSize_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('StockTakeSheetParameters_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('TaskDetail_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('TaskManagerReason_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('TaskManagerUser_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('TaskManagerUserDetail_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('WAVE_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('WAVEDETAIL_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('ID_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('LOT_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('LOTxLOCxID_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('PackConfig')
   INSERT INTO #StandardTable( TableName) VALUES ('SAP_ITEM')
   INSERT INTO #StandardTable( TableName) VALUES ('SAP_LOC') -- temp for PH ULP migration
   INSERT INTO #StandardTable( TableName) VALUES ('BONDSKU') -- UK
   INSERT INTO #StandardTable( TableName) VALUES ('OrderDetailRef') -- US
   INSERT INTO #StandardTable( TableName) VALUES ('rdtSpoolerLog') -- UK
   INSERT INTO #StandardTable( TableName) VALUES ('RouteMaster_DELLOG')  -- DM
   INSERT INTO #StandardTable( TableName) VALUES ('EC_OrderDet')  -- TW EWMS
   INSERT INTO #StandardTable( TableName) VALUES ('EC_Orders')
   INSERT INTO #StandardTable( TableName) VALUES ('EC_UserRestrict')
   INSERT INTO #StandardTable( TableName) VALUES ('CBOL')
   INSERT INTO #StandardTable( TableName) VALUES ('IDS_MenuGroup')
   INSERT INTO #StandardTable( TableName) VALUES ('IDS_MenuItem')
   INSERT INTO #StandardTable( TableName) VALUES ('IDS_MenuLink')
   INSERT INTO #StandardTable( TableName) VALUES ('IDS_MenuUser')
   INSERT INTO #StandardTable( TableName) VALUES ('DEL_REPLENISHMENT')
   INSERT INTO #StandardTable( TableName) VALUES ('PackDetail_Log')  -- UK
   INSERT INTO #StandardTable( TableName) VALUES ('Temp_ReplenTrace')  -- UK
   INSERT INTO #StandardTable( TableName) VALUES ('XML_Message') -- US
   INSERT INTO #StandardTable( TableName) VALUES ('rdtSpoolerLog')  -- UK
   INSERT INTO #StandardTable( TableName) VALUES ('PICKDET_LOG_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('StorerConfig_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('IDS_VEHICLE_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('EC_InventoryHold')  -- eWMS
   INSERT INTO #StandardTable( TableName) VALUES ('CartonShipmentDetail')  -- Skipjack
   INSERT INTO #StandardTable( TableName) VALUES ('FedexTracking')
   INSERT INTO #StandardTable( TableName) VALUES ('VAS')
   INSERT INTO #StandardTable( TableName) VALUES ('UPSTracking_Out')
   INSERT INTO #StandardTable( TableName) VALUES ('UPSTracking_In')
   INSERT INTO #StandardTable( TableName) VALUES ('CartonShipmentDetail_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('OrderInfo_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('TMPermissionProfile')  -- UK Task permission assignment
   INSERT INTO #StandardTable( TableName) VALUES ('TMPermissionProfileDetail')
   INSERT INTO #StandardTable( TableName) VALUES ('RDTLoginLog')  -- UK
   INSERT INTO #StandardTable( TableName) VALUES ('TCPSocket_INLog')   -- Skipjack
   INSERT INTO #StandardTable( TableName) VALUES ('TCPSocket_OUTLog')  -- Skipjack
   INSERT INTO #StandardTable( TableName) VALUES ('TCPSocket_Process') -- Skipjack
   INSERT INTO #StandardTable( TableName) VALUES ('rdtMasterPackLog')  -- Skipjack
   INSERT INTO #StandardTable( TableName) VALUES ('WCS_SORTATION')     -- SkipJack
   INSERT INTO #StandardTable( TableName) VALUES ('TempFedExProcessShipmentLog') -- FedEx WebService
   INSERT INTO #StandardTable( TableName) VALUES ('StockTakeSheetParameters_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('UPSReturnTrackNo')
   INSERT INTO #StandardTable( TableName) VALUES ('Dropid_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('DropidDetail_DELLOG')
   INSERT INTO #StandardTable( TableName) VALUES ('ShortPickLog')
   INSERT INTO #StandardTable( TableName) VALUES ('MBOLErrorReport')
   INSERT INTO #StandardTable( TableName) VALUES ('DEL_RefKeyLookup')
   INSERT INTO #StandardTable( TableName) VALUES ('GS1BatchNo')
   INSERT INTO #StandardTable( TableName) VALUES ('PickDetail_Log')
   INSERT INTO #StandardTable( TableName) VALUES ('WaveRelErrorReport')
   INSERT INTO #StandardTable( TableName) VALUES ('WCS_ResidualMoveLog')
   INSERT INTO #StandardTable( TableName) VALUES ('rdtQCLog')
   INSERT INTO #StandardTable( TableName) VALUES ('GenericWebServiceHost_Process')   
   INSERT INTO #StandardTable( TableName) VALUES ('CONTAINER_DELLOG')  
   INSERT INTO #StandardTable( TableName) VALUES ('CONTAINERDETAIL_DELLOG')  
   INSERT INTO #StandardTable( TableName) VALUES ('PALLET_DELLOG')  
   INSERT INTO #StandardTable( TableName) VALUES ('PALLETDETAIL_DELLOG')  
   INSERT INTO #StandardTable( TableName) VALUES ('Booking_BlockSlot')
   INSERT INTO #StandardTable( TableName) VALUES ('Booking_In')
   INSERT INTO #StandardTable( TableName) VALUES ('Booking_Out')
   INSERT INTO #StandardTable( TableName) VALUES ('Booking_PO')
   INSERT INTO #StandardTable( TableName) VALUES ('UnpickMoveLog')
   INSERT INTO #StandardTable( TableName) VALUES ('SkuInfo')   -- SOS244027
   INSERT INTO #StandardTable( TableName) VALUES ('TriganticLogKey')   -- CN   
   INSERT INTO #StandardTable( TableName) VALUES ('LOTxLOCxID_B4Post')    -- US
   INSERT INTO #StandardTable( TableName) VALUES ('StockTakeErrorReport') 
   INSERT INTO #StandardTable( TableName) VALUES ('CCDetail_B4Post') 
   INSERT INTO #StandardTable( TableName) VALUES ('DeviceProfile')    -- Put to Light
   INSERT INTO #StandardTable( TableName) VALUES ('DeviceProfileLog') 
   INSERT INTO #StandardTable( TableName) VALUES ('PTLTran') 
   INSERT INTO #StandardTable( TableName) VALUES ('ITRNKey')      -- GetKey Enhance
   INSERT INTO #StandardTable( TableName) VALUES ('PickDetailKey')      -- GetKey Enhance
   INSERT INTO #StandardTable( TableName) VALUES ('PreallocatePickDetailKey')      -- GetKey Enhance
   INSERT INTO #StandardTable( TableName) VALUES ('TaskdetailKey')      -- GetKey Enhance
   INSERT INTO #StandardTable( TableName) VALUES ('TransmitlogKey')      -- GetKey Enhance
   INSERT INTO #StandardTable( TableName) VALUES ('TransmitlogKey2')      -- GetKey Enhance
   INSERT INTO #StandardTable( TableName) VALUES ('TransmitlogKey3')      -- GetKey Enhance
   INSERT INTO #StandardTable( TableName) VALUES ('WMSCustITRAN')      -- PH interface
   INSERT INTO #StandardTable( TableName) VALUES ('StorerGroup')      -- HK
   INSERT INTO #StandardTable( TableName) VALUES ('rdtMoveToIDLog')      -- VF
   INSERT INTO #StandardTable( TableName) VALUES ('rdtPAFSwapTaskLog')      -- VF
   INSERT INTO #StandardTable( TableName) VALUES ('rdtRPFLog')      -- VF
   INSERT INTO #StandardTable( TableName) VALUES ('rdtSortLaneLocLog')      -- VF
   INSERT INTO #StandardTable( TableName) VALUES ('rdtTrolleyLog')      -- VF
   INSERT INTO #StandardTable( TableName) VALUES ('rdtUCCSwapLog')      -- VF
   INSERT INTO #StandardTable( TableName) VALUES ('CheckUpKPI')      -- KPI check
   INSERT INTO #StandardTable( TableName) VALUES ('CheckUpKPIDetail')      -- KPI check
   INSERT INTO #StandardTable( TableName) VALUES ('LOTKEY')      -- GetKey Enhance
   INSERT INTO #StandardTable( TableName) VALUES ('Booking_Audit')   
   INSERT INTO #StandardTable( TableName) VALUES ('BartenderCmdConfig')   
   INSERT INTO #StandardTable( TableName) VALUES ('BartenderLabelCfg')   
   INSERT INTO #StandardTable( TableName) VALUES ('Booking_InDetail')   --  eWMS
   INSERT INTO #StandardTable( TableName) VALUES ('BookingSeqConfig')   -- RDT Booking
   INSERT INTO #StandardTable( TableName) VALUES ('DEL_SerialNo')   -- SG
   INSERT INTO #StandardTable( TableName) VALUES ('rdtAssignLoc')   -- ANF
   INSERT INTO #StandardTable( TableName) VALUES ('TCPOUTLogKey')   -- getkey
   INSERT INTO #StandardTable( TableName) VALUES ('ABCAnalysis')   -- ABCAnalysis
   INSERT INTO #StandardTable( TableName) VALUES ('ABCTran')   -- ABCAnalysis
   INSERT INTO #StandardTable( TableName) VALUES ('NONINV')   -- ABCAnalysis
   INSERT INTO #StandardTable( TableName) VALUES ('NONITRN')   -- ABCAnalysis
   INSERT INTO #StandardTable( TableName) VALUES ('WorkOrderInputs')   -- WorkStation
   INSERT INTO #StandardTable( TableName) VALUES ('WorkOrderJob')   -- WorkStation
   INSERT INTO #StandardTable( TableName) VALUES ('WorkOrderJobDetail')   -- WorkStation
   INSERT INTO #StandardTable( TableName) VALUES ('WorkOrderJobMove')   -- WorkStation
   INSERT INTO #StandardTable( TableName) VALUES ('WorkOrderJobOperation')   -- WorkStation
   INSERT INTO #StandardTable( TableName) VALUES ('WorkOrderOutputs')   -- WorkStation
   INSERT INTO #StandardTable( TableName) VALUES ('WorkOrderRequestInputs')   -- WorkStation
   INSERT INTO #StandardTable( TableName) VALUES ('WorkOrderRouting')   -- WorkStation
   INSERT INTO #StandardTable( TableName) VALUES ('WorkOrderSteps')   -- WorkStation            
   INSERT INTO #StandardTable( TableName) VALUES ('WorkOrderPackets')   -- WorkStation  
   INSERT INTO #StandardTable( TableName) VALUES ('WorkOrderRequest')   -- WorkStation  
   INSERT INTO #StandardTable( TableName) VALUES ('WorkOrderRequestOutputs')   -- WorkStation        
   INSERT INTO #StandardTable( TableName) VALUES ('WorkStation')   -- WorkStation               
   INSERT INTO #StandardTable( TableName) VALUES ('WORKSTATIONLOC')   -- WorkStation                  
   INSERT INTO #StandardTable( TableName) VALUES ('ITFTriggerConfig')   --                   
   INSERT INTO #StandardTable( TableName) VALUES ('rdtPickConsoLog')   --                   
   INSERT INTO #StandardTable( TableName) VALUES ('rdtUCCPreRCVAuditLog')   --                   
   INSERT INTO #StandardTable( TableName) VALUES ('RFPutawayNMV')   --                   
   INSERT INTO #StandardTable( TableName) VALUES ('RDTDynamicPickLog_DELLOG')   --                   
   INSERT INTO #StandardTable( TableName) VALUES ('RFPUTAWAY_DELLOG')   --                   
   INSERT INTO #StandardTable( TableName) VALUES ('rdtFPKLog')   --                   
   INSERT INTO #StandardTable( TableName) VALUES ('DOCINFO')   --           
   INSERT INTO #StandardTable( TableName) VALUES ('DocStatusTrack')   --     Generic Doc tracking - replace Trigantics
   INSERT INTO #StandardTable( TableName) VALUES ('SerialNo_DELLOG')   --           
   INSERT INTO #StandardTable( TableName) VALUES ('PICKSLIPKey')   --           
   INSERT INTO #StandardTable( TableName) VALUES ('WCSKey')   --           
   INSERT INTO #StandardTable( TableName) VALUES ('RDTPPA_DELLOG')   --           
   INSERT INTO #StandardTable( TableName) VALUES ('rdtFCPLog')   -- 
   INSERT INTO #StandardTable( TableName) VALUES ('rdtLottableCode')   -- 
   INSERT INTO #StandardTable( TableName) VALUES ('VoiceAssignment')   -- 
   INSERT INTO #StandardTable( TableName) VALUES ('VoiceAssignmentDetail')   -- 
   INSERT INTO #StandardTable( TableName) VALUES ('VoiceConfig')   -- 
   INSERT INTO #StandardTable( TableName) VALUES ('PTLLockLoc')   -- 
   INSERT INTO #StandardTable( TableName) VALUES ('PTLTranLog')   -- 
   INSERT INTO #StandardTable( TableName) VALUES ('LFLightLink_INLOG')   -- 
   INSERT INTO #StandardTable( TableName) VALUES ('rdtMVFLog')   -- 
   INSERT INTO #StandardTable( TableName) VALUES ('CartonTrack_Pool')   --                    
   INSERT INTO #StandardTable( TableName) VALUES ('ReceiptInfo')   --                    
   INSERT INTO #StandardTable( TableName) VALUES ('TableActionLog')   --                    
   INSERT INTO #StandardTable( TableName) VALUES ('rdtPTLCartLog')   --                    
   INSERT INTO #StandardTable( TableName) VALUES ('OTMLOG')   --                    
   INSERT INTO #StandardTable( TableName) VALUES ('ModuleReports')   --  CN New Build Load                  
   INSERT INTO #StandardTable( TableName) VALUES ('MoveRefKey')   --   getkey                 
   INSERT INTO #StandardTable( TableName) VALUES ('rdtReplenishmentLog')   --                    
   INSERT INTO #StandardTable( TableName) VALUES ('rdtConReceiveLog')   --                    
   INSERT INTO #StandardTable( TableName) VALUES ('PALLETIMAGE')   --                    
   INSERT INTO #StandardTable( TableName) VALUES ('GTMTask')   --      Merlion               
   INSERT INTO #StandardTable( TableName) VALUES ('WCSTran')   --      Merlion               
   INSERT INTO #StandardTable( TableName) VALUES ('Orderkey')   --                    
   INSERT INTO #StandardTable( TableName) VALUES ('GTMLog')   --      Merlion               
   INSERT INTO #StandardTable( TableName) VALUES ('rdtPalletReceiveLog')   --      Merlion
   INSERT INTO #StandardTable( TableName) VALUES ('VehicleDispatch')   --      Merlion
   INSERT INTO #StandardTable( TableName) VALUES ('VehicleDispatchDetail')   --      Merlion   
   INSERT INTO #StandardTable( TableName) VALUES ('BartenderPrinterLog')   --         
   INSERT INTO #StandardTable( TableName) VALUES ('GTMLoop')   ---      Merlion    
   INSERT INTO #StandardTable( TableName) VALUES ('rdtPACartLog')   ---      TW    
   INSERT INTO #StandardTable( TableName) VALUES ('ULMRFPUTAWAY')   ---      TW    
   INSERT INTO #StandardTable( TableName) VALUES ('IDS_LP_DRIVER_DELLOG')   ---          
   INSERT INTO #StandardTable( TableName) VALUES ('IDS_LP_VEHICLE_DELLOG')   ---          
   INSERT INTO #StandardTable( TableName) VALUES ('LFLightLinkLOG')   ---      TW    
   INSERT INTO #StandardTable( TableName) VALUES ('LightInput')   ---      TW    
   INSERT INTO #StandardTable( TableName) VALUES ('LightMode')   ---          
   INSERT INTO #StandardTable( TableName) VALUES ('LightStatus')   ---          
   INSERT INTO #StandardTable( TableName) VALUES ('VASRefKeyLookup')   ---          
   INSERT INTO #StandardTable( TableName) VALUES ('WORKORDERJOBRECON')   ---          
   INSERT INTO #StandardTable( TableName) VALUES ('OTMIDTrack')   ---     
   INSERT INTO #StandardTable( TableName) VALUES ('WebService_LOG')   ---          
   INSERT INTO #StandardTable( TableName) VALUES ('sysobjects')   ---         
   INSERT INTO #StandardTable( TableName) VALUES ('WorkOrder_Palletize')   ---         
   INSERT INTO #StandardTable( TableName) VALUES ('WorkOrder_UnCasing')   ---         
   INSERT INTO #StandardTable( TableName) VALUES ('WorkStation_LOG')   ---         
   INSERT INTO #StandardTable( TableName) VALUES ('PalletLabel')   ---         
   INSERT INTO #StandardTable( TableName) VALUES ('JobTaskLookup')   ---         
   INSERT INTO #StandardTable( TableName) VALUES ('WorkOrderJobMove_DELLOG')   ---         
   INSERT INTO #StandardTable( TableName) VALUES ('AreaDetail_DELLOG')   ---         
   INSERT INTO #StandardTable( TableName) VALUES ('SKUConfig_DELLOG')   ---         
   INSERT INTO #StandardTable( TableName) VALUES ('CourierSortingCode')   ---         
   INSERT INTO #StandardTable( TableName) VALUES ('rdtreceiptlog')   ---      SOS364495   
   INSERT INTO #StandardTable( TableName) VALUES ('rdtPTLStationLog')       
   INSERT INTO #StandardTable( TableName) VALUES ('EC_RECEIPT')   ---      CR332795   
   INSERT INTO #StandardTable( TableName) VALUES ('EC_RECEIPTDETAIL')   ---      CR332795   
   INSERT INTO #StandardTable( TableName) VALUES ('BarcodeConfig')   ---      CR332795   
   INSERT INTO #StandardTable( TableName) VALUES ('BarcodeConfigDetail')   ---      CR332795   
   INSERT INTO #StandardTable( TableName) VALUES ('PALLETMGMT')   ---      CR332795   
   INSERT INTO #StandardTable( TableName) VALUES ('PALLETMGMTDETAIL')   ---      CR332795   
   INSERT INTO #StandardTable( TableName) VALUES ('PMINV')   ---      CR332795   
   INSERT INTO #StandardTable( TableName) VALUES ('PMTRN')   ---      CR332795   
   INSERT INTO #StandardTable( TableName) VALUES ('Brokerage')   ---          
   INSERT INTO #StandardTable( TableName) VALUES ('BrokerageDetail')   ---          
   INSERT INTO #StandardTable( TableName) VALUES ('PackTask')   ---          
   INSERT INTO #StandardTable( TableName) VALUES ('ExceptionHandling')   ---       
   INSERT INTO #StandardTable( TableName) VALUES ('PickDetail_WIP')   ---          
   INSERT INTO #StandardTable( TableName) VALUES ('STOCKTAKEPARMSTRATEGY')   ---         
   INSERT INTO #StandardTable( TableName) VALUES ('OrderSelectionCondition')   ---         
   INSERT INTO #StandardTable( TableName) VALUES ('PACKTASKDETAIL')   ---         
   INSERT INTO #StandardTable( TableName) VALUES ('QCmd_TransmitlogConfig')   ---         
   INSERT INTO #StandardTable( TableName) VALUES ('TCPSocket_QueueTask')   ---         
   INSERT INTO #StandardTable( TableName) VALUES ('rdtCarterCubicGroupLog')   ---         
   INSERT INTO #StandardTable( TableName) VALUES ('rdtPTLPieceLog')   ---         
   INSERT INTO #StandardTable( TableName) VALUES ('rdtPTLStationLog_DELLOG')   ---         
   INSERT INTO #StandardTable( TableName) VALUES ('LoadPlan_SUP_Detail')   ---         
   INSERT INTO #StandardTable( TableName) VALUES ('BuildLoadLog')   ---
   INSERT INTO #StandardTable( TableName) VALUES ('BuildLoadDetailLog')   ---                                  
   INSERT INTO #StandardTable( TableName) VALUES ('rdtPTSLog')   ---
   INSERT INTO #StandardTable( TableName) VALUES ('SQLObjectRights')   ---   
   INSERT INTO #StandardTable( TableName) VALUES ('rdtSortCaseLog')   ---   
   INSERT INTO #StandardTable( TableName) VALUES ('BTB_FTA')   ---      Logitec
   INSERT INTO #StandardTable( TableName) VALUES ('CartonList')   ---      
   INSERT INTO #StandardTable( TableName) VALUES ('CartonListDetail')   ---      
   INSERT INTO #StandardTable( TableName) VALUES ('MasterSerialNo')   ---  Logitec    
   INSERT INTO #StandardTable( TableName) VALUES ('BTB_Shipment')   ---      
   INSERT INTO #StandardTable( TableName) VALUES ('BTB_ShipmentDetail')   ---      
   INSERT INTO #StandardTable( TableName) VALUES ('BTB_ShipmentList')   ---  Logitec    
   INSERT INTO #StandardTable( TableName) VALUES ('rdtPrinterGroup')   ---      
   INSERT INTO #StandardTable( TableName) VALUES ('rdtReportToPrinter')   ---      
   INSERT INTO #StandardTable( TableName) VALUES ('rdtSpooler')   ---  Logitec    
   INSERT INTO #StandardTable( TableName) VALUES ('SerialNoKey')   ---  Logitec    
   INSERT INTO #StandardTable( TableName) VALUES ('TransactionLog')   ---  mobile dashboard    
   INSERT INTO #StandardTable( TableName) VALUES ('UserRestrictions')   ---  mobile dashboard
   INSERT INTO #StandardTable( TableName) VALUES ('rdtFCPLog')   ---   PH Colgate
   INSERT INTO #StandardTable( TableName) VALUES ('ReceiptSerialNo')   ---   Dyson
   INSERT INTO #StandardTable( TableName) VALUES ('ITrnSerialNo')   ---   Dyson
   INSERT INTO #StandardTable( TableName) VALUES ('PackSerialNo')   ---   Dyson   
   INSERT INTO #StandardTable( TableName) VALUES ('REPLENISHKEY')   ---   TH Tune   
   INSERT INTO #StandardTable( TableName) VALUES ('EPACKPFTDATA')   ---   ECom packing  
   INSERT INTO #StandardTable( TableName) VALUES ('rdtUCCReceive2Log')   ---     
   INSERT INTO #StandardTable( TableName) VALUES ('rdtSerialNoLog')   ---   Dyson  
   INSERT INTO #StandardTable( TableName) VALUES ('MasterSerialNoTrn')   ---   Dyson  
   INSERT INTO #StandardTable( TableName) VALUES ('ORDERS_TRACKNO_WIP')   ---   Ecom new process  
   INSERT INTO #StandardTable( TableName) VALUES ('AutoAllocBatch')   ---   Ecom new process  
   INSERT INTO #StandardTable( TableName) VALUES ('AutoAllocBatchDetail')   ---   Ecom new process  
   INSERT INTO #StandardTable( TableName) VALUES ('TCPSocket_QueueTask_Log')   ---   Ecom new process  
   INSERT INTO #StandardTable( TableName) VALUES ('AutoAllocBatchJob')   ---   Ecom new process  
   INSERT INTO #StandardTable( TableName) VALUES ('TPB_Config')   ---   TPB new process  
   INSERT INTO #StandardTable( TableName) VALUES ('WMS_TPB_BASE')   ---   TPB new process  
   INSERT INTO #StandardTable( TableName) VALUES ('TPB_Data_Batch')   ---   TPB new process  
   INSERT INTO #StandardTable( TableName) VALUES ('TPB_EXTRACTION_HISTORY')   ---   TPB new process  
    INSERT INTO #StandardTable( TableName) VALUES ('rdtMoveSerialNoLog')    
    INSERT INTO #StandardTable( TableName) VALUES ('rdtPreReceiveSort2Log')    
    INSERT INTO #StandardTable( TableName) VALUES ('LEAF_Chart_DET')    
    INSERT INTO #StandardTable( TableName) VALUES ('LEAF_Chart_HDR')    
    INSERT INTO #StandardTable( TableName) VALUES ('LWMS_WebApiConfig')            
    INSERT INTO #StandardTable( TableName) VALUES ('GVDocEventLog')            
    INSERT INTO #StandardTable( TableName) VALUES ('rdtSortAndPackLog')    

    INSERT INTO #StandardTable( TableName) VALUES ('AutoAllocBatch')    
    INSERT INTO #StandardTable( TableName) VALUES ('AutoAllocBatchDetail')    
    INSERT INTO #StandardTable( TableName) VALUES ('AutoAllocBatchDetail_Log')    
    INSERT INTO #StandardTable( TableName) VALUES ('AutoAllocBatchJob')    
    INSERT INTO #StandardTable( TableName) VALUES ('AutoAllocBatchJob_Log')     

    INSERT INTO #StandardTable( TableName) VALUES ('PACKDet')  
       
    INSERT INTO #StandardTable( TableName) VALUES ('BuildParm')     
    INSERT INTO #StandardTable( TableName) VALUES ('BuildParmDetail')     
    INSERT INTO #StandardTable( TableName) VALUES ('BuildParmGroupCfg')   
    INSERT INTO #StandardTable( TableName) VALUES ('MailQ')          
    INSERT INTO #StandardTable( TableName) VALUES ('MailQDet')                            
                
    INSERT INTO #StandardTable( TableName) VALUES ('PhotoRepo_Users')      --Photo Repository ( Web Application) security and account     
    INSERT INTO #StandardTable( TableName) VALUES ('PhotoRepo_Account')                            
    INSERT INTO #StandardTable( TableName) VALUES ('itfSQLAutoReportExport')                            
    INSERT INTO #StandardTable( TableName) VALUES ('rdtSTDEventLogLookUp')                               
    INSERT INTO #StandardTable( TableName) VALUES ('rdtReceivekSerialNoLog')                        


     INSERT INTO #StandardTable( TableName) VALUES ('ChannelAttributeConfig')                        
     INSERT INTO #StandardTable( TableName) VALUES ('ChannelInv')   
      INSERT INTO #StandardTable( TableName) VALUES ('ChannelItran')   
      INSERT INTO #StandardTable( TableName) VALUES ('ChannelTransfer')   
      INSERT INTO #StandardTable( TableName) VALUES ('ChannelTransferDetail')   

      INSERT INTO #StandardTable( TableName) VALUES ('rdtReceiveSerialNoLog')   
                      
    INSERT INTO #StandardTable( TableName) VALUES ('AutoAllocBatch_Log')   
    INSERT INTO #StandardTable( TableName) VALUES ('IDKey')   
    INSERT INTO #StandardTable( TableName) VALUES ('LogError')   
    INSERT INTO #StandardTable( TableName) VALUES ('LogSQL')   
    INSERT INTO #StandardTable( TableName) VALUES ('Orders_Staging')   
    INSERT INTO #StandardTable( TableName) VALUES ('Orders_StagingNum')   
    INSERT INTO #StandardTable( TableName) VALUES ('Orders_SUM_SnapShot')   
    INSERT INTO #StandardTable( TableName) VALUES ('QCSvcConfig')   
    INSERT INTO #StandardTable( TableName) VALUES ('QCSvcDBConfig')   
    INSERT INTO #StandardTable( TableName) VALUES ('QCSvcTCPClientConfig')   
    INSERT INTO #StandardTable( TableName) VALUES ('RDTPrintJob_Log')   
    INSERT INTO #StandardTable( TableName) VALUES ('ReceiptKey')   
    INSERT INTO #StandardTable( TableName) VALUES ('eCom_Job_Config')       
    INSERT INTO #StandardTable( TableName) VALUES ('rdtPTLCartLog_Doc')       
    INSERT INTO #StandardTable( TableName) VALUES ('rdtSortCaseLock')       
    INSERT INTO #StandardTable( TableName) VALUES ('TBL_PURGECONFIG')                

    INSERT INTO #StandardTable( TableName) VALUES ('TBL_PURGECONFIG')     
    INSERT INTO #StandardTable( TableName) VALUES ('WMS_ConnectionThread')     
    INSERT INTO #StandardTable( TableName) VALUES ('WMS_Connection_Sum')     

    INSERT INTO #StandardTable( TableName) VALUES ('PickZone')     
    INSERT INTO #StandardTable( TableName) VALUES ('PIZoneEquipmentExcludeDetail')     
    INSERT INTO #StandardTable( TableName) VALUES ('SEQKey')     
    INSERT INTO #StandardTable( TableName) VALUES ('ExternLotAttribute')     
    INSERT INTO #StandardTable( TableName) VALUES ('rdtFPKLog')     
  
    INSERT INTO #StandardTable( TableName) VALUES ('GVTLog')     
  
    INSERT INTO #StandardTable( TableName) VALUES ('PackDetailInfo')     
    INSERT INTO #StandardTable( TableName) VALUES ('rdtSerialNoCaptureByOrderSKULog')     
    INSERT INTO #StandardTable( TableName) VALUES ('TH_CustomerLotInfo')     
  
    INSERT INTO #StandardTable( TableName) VALUES ('OrdersV2Agg')      
    INSERT INTO #StandardTable( TableName) VALUES ('OrdersV2AggNum')       
    INSERT INTO #StandardTable( TableName) VALUES ('OrdersV2Raw')      
    INSERT INTO #StandardTable( TableName) VALUES ('OrdersV2Status')      
    INSERT INTO #StandardTable( TableName) VALUES ('OrdersV2Sum')      
    
    INSERT INTO #StandardTable( TableName) VALUES ('BUILDWAVEDETAILLOG')      
    INSERT INTO #StandardTable( TableName) VALUES ('BUILDWAVELOG')      
    INSERT INTO #StandardTable( TableName) VALUES ('ChannelInvHold')      
    INSERT INTO #StandardTable( TableName) VALUES ('ChannelInvHoldDetail')      
    INSERT INTO #StandardTable( TableName) VALUES ('DailyInventoryChannel')      
    INSERT INTO #StandardTable( TableName) VALUES ('GENREPLENISHMENTLOG')      
    INSERT INTO #StandardTable( TableName) VALUES ('RDTWatTeamLog')      
    INSERT INTO #StandardTable( TableName) VALUES ('REPLENISHMENTPARMS')      
    INSERT INTO #StandardTable( TableName) VALUES ('REPLENISHSTRATEGY')      
    INSERT INTO #StandardTable( TableName) VALUES ('REPLENISHSTRATEGYDETAIL')      
    INSERT INTO #StandardTable( TableName) VALUES ('TaskDetail_WIP')      
    INSERT INTO #StandardTable( TableName) VALUES ('WMREPORT')         
    INSERT INTO #StandardTable( TableName) VALUES ('WMREPORTDETAIL')         
    INSERT INTO #StandardTable( TableName) VALUES ('WMS_Error_List')         
    INSERT INTO #StandardTable( TableName) VALUES ('WMS_TABLE_EVENT_CONFIG')        
    INSERT INTO #StandardTable( TableName) VALUES ('WMS_USER_CREATION_STATUS') 
    INSERT INTO #StandardTable( TableName) VALUES ('Orders_Encrypt')     
    INSERT INTO #StandardTable( TableName) VALUES ('OrderToLocDetail')     
    INSERT INTO #StandardTable( TableName) VALUES ('PTLTrafficDetail')     
    INSERT INTO #StandardTable( TableName) VALUES ('RDTMobRec_LOG')     
    INSERT INTO #StandardTable( TableName) VALUES ('AutoAllocStatus')     
    INSERT INTO #StandardTable( TableName) VALUES ('ExcelGenerator')     
    INSERT INTO #StandardTable( TableName) VALUES ('ExcelGeneratorDetail')     
    INSERT INTO #StandardTable( TableName) VALUES ('GeekPlusRBT_InvSync')    
    INSERT INTO #StandardTable( TableName) VALUES ('rdtCPVAdjustmentLog')     
    INSERT INTO #StandardTable( TableName) VALUES ('rdtCPVKitLog')     
    INSERT INTO #StandardTable( TableName) VALUES ('rdtCPVOrderLog')     
    INSERT INTO #StandardTable( TableName) VALUES ('LFLightLink_LOG') 
    INSERT INTO #StandardTable( TableName) VALUES ('eComConfig')
    INSERT INTO #StandardTable( TableName) VALUES ('eComPromo')
    INSERT INTO #StandardTable( TableName) VALUES ('idsMEDSKU')
    INSERT INTO #StandardTable( TableName) VALUES ('IMLAgg')
    INSERT INTO #StandardTable( TableName) VALUES ('IMLAggLog')
    INSERT INTO #StandardTable( TableName) VALUES ('MailQSMS')
    INSERT INTO #StandardTable( TableName) VALUES ('MailQSMSDet')
    INSERT INTO #StandardTable( TableName) VALUES ('Orders_PI_Encrypted')
    INSERT INTO #StandardTable( TableName) VALUES ('OrderStage')
    INSERT INTO #StandardTable( TableName) VALUES ('OrderSum')
    INSERT INTO #StandardTable( TableName) VALUES ('rdtCaseIDCaptureLog')
    INSERT INTO #StandardTable( TableName) VALUES ('rdtPFLStationLog')
    INSERT INTO #StandardTable( TableName) VALUES ('rdtPPALog')
    INSERT INTO #StandardTable( TableName) VALUES ('RDTReceiveAudit')
    INSERT INTO #StandardTable( TableName) VALUES ('SimulationCriteria')
    INSERT INTO #StandardTable( TableName) VALUES ('TMS_Shipment')
    INSERT INTO #StandardTable( TableName) VALUES ('TMS_ShipmentTransOrderLink')
    INSERT INTO #StandardTable( TableName) VALUES ('TMS_TransportOrder')
    INSERT INTO #StandardTable( TableName) VALUES ('VAS_Demand')
    INSERT INTO #StandardTable( TableName) VALUES ('VAS_Plan')
    INSERT INTO #StandardTable( TableName) VALUES ('VAS_Productivity')
    INSERT INTO #StandardTable( TableName) VALUES ('captured_columns')
    INSERT INTO #StandardTable( TableName) VALUES ('change_tables')
    INSERT INTO #StandardTable( TableName) VALUES ('dbo_BuildLoadLog_CT')
    INSERT INTO #StandardTable( TableName) VALUES ('dbo_CODELKUP_CT')
    INSERT INTO #StandardTable( TableName) VALUES ('ddl_history')
    INSERT INTO #StandardTable( TableName) VALUES ('index_columns')
    INSERT INTO #StandardTable( TableName) VALUES ('lsn_time_mapping')
    INSERT INTO #StandardTable( TableName) VALUES ('systranschemas')
    INSERT INTO #StandardTable( TableName) VALUES ('rdtPreReceiveSort')
    INSERT INTO #StandardTable( TableName) VALUES ('EXG_FileDet')
    INSERT INTO #StandardTable( TableName) VALUES ('EXG_FileHdr')
    INSERT INTO #StandardTable( TableName) VALUES ('ITrnUCC')
    INSERT INTO #StandardTable( TableName) VALUES ('CARTONIZATION_DELLOG')
    INSERT INTO #StandardTable( TableName) VALUES ('TrackingID')
    INSERT INTO #StandardTable( TableName) VALUES ('GEEKPBOT_INTEG_CONFIG')
    INSERT INTO #StandardTable( TableName) VALUES ('View_JReport') 
    INSERT INTO #StandardTable( TableName) VALUES ('JReportFolder')      
    INSERT INTO #StandardTable( TableName) VALUES ('rdtPreReceiveSort_DELLOG')      
       
     --  WMS-14463
    INSERT INTO #StandardTable( TableName) VALUES ('ExternOrders') 
    INSERT INTO #StandardTable( TableName) VALUES ('ExternOrdersDetail') 
    INSERT INTO #StandardTable( TableName) VALUES ('RFIDMaster') 
    INSERT INTO #StandardTable( TableName) VALUES ('RFIDTransLog') 
    INSERT INTO #StandardTable( TableName) VALUES ('PACKQRF') 
    INSERT INTO #StandardTable( TableName) VALUES ('DBStatusTrack') 
    INSERT INTO #StandardTable( TableName) VALUES ('DailyInventoryChannel_DELLOG') 
    INSERT INTO #StandardTable( TableName) VALUES ('RDTPickQCLog') 
    INSERT INTO #StandardTable( TableName) VALUES ('rdtSortAndPackLOC') 
    INSERT INTO #StandardTable( TableName) VALUES ('rdtTruckPackInfo') 
    INSERT INTO #StandardTable( TableName) VALUES ('BTB_FTA_DELLOG') 
    INSERT INTO #StandardTable( TableName) VALUES ('AppPrinter') 
    INSERT INTO #StandardTable( TableName) VALUES ('AppSection') 
    INSERT INTO #StandardTable( TableName) VALUES ('AppWorkstation') 
    INSERT INTO #StandardTable( TableName) VALUES ('RECEIPTDETAIL_WIP') 
    INSERT INTO #StandardTable( TableName) VALUES ('GWPTrack') 
    INSERT INTO #StandardTable( TableName) VALUES ('PickingVoice') 
    INSERT INTO #StandardTable( TableName) VALUES ('ExecutionLog') 
    INSERT INTO #StandardTable( TableName) VALUES ('STG_DocStatusTrack') 
    INSERT INTO #StandardTable( TableName) VALUES ('SkuImage') 
    INSERT INTO #StandardTable( TableName) VALUES ('rdtPTLStationLogQueue') 
    INSERT INTO #StandardTable( TableName) VALUES ('rdtReportDetail') 
    INSERT INTO #StandardTable( TableName) VALUES ('WebSocket_INLog') 
    INSERT INTO #StandardTable( TableName) VALUES ('WebSocket_OUTLog')    

    INSERT INTO #StandardTable( TableName) VALUES ('TPPRINTCMDLOG') 
    INSERT INTO #StandardTable( TableName) VALUES ('TPPRINTCONFIG') 
    INSERT INTO #StandardTable( TableName) VALUES ('TPPRINTERGROUP')    
    INSERT INTO #StandardTable( TableName) VALUES ('TPPRINTJOB')    
    INSERT INTO #StandardTable( TableName) VALUES ('AppWorkStation_Log')    
    INSERT INTO #StandardTable( TableName) VALUES ('PackdetailLabel')    
    INSERT INTO #StandardTable( TableName) VALUES ('rdtMoveToLOCLog')    
    INSERT INTO #StandardTable( TableName) VALUES ('SCE_DL_EO')    
    INSERT INTO #StandardTable( TableName) VALUES ('SCE_DL_EO_STG')    

    INSERT INTO #StandardTable( TableName) VALUES ('SCE_DL_ASN')    
    INSERT INTO #StandardTable( TableName) VALUES ('SCE_DL_LOC')    
    INSERT INTO #StandardTable( TableName) VALUES ('SCE_DL_PO')    
    INSERT INTO #StandardTable( TableName) VALUES ('SCE_DL_SKU')    
    INSERT INTO #StandardTable( TableName) VALUES ('SCE_DL_SO')    
   
    INSERT INTO #StandardTable( TableName) VALUES ('CODELIST_DELLOG')    
    INSERT INTO #StandardTable( TableName) VALUES ('rdtECOMQABatchLog')    
    INSERT INTO #StandardTable( TableName) VALUES ('SCE_DL_AssignLane')    
    
    INSERT INTO #StandardTable( TableName) VALUES ('AllocateStrategy_DELLOG')        
    INSERT INTO #StandardTable( TableName) VALUES ('AllocateStrategyDetail_DELLOG') 
    INSERT INTO #StandardTable( TableName) VALUES ('PickZone_DELLOG')
    INSERT INTO #StandardTable( TableName) VALUES ('PreAllocateStrategy_DELLOG')
    INSERT INTO #StandardTable( TableName) VALUES ('PreAllocateStrategyDetail_DELLOG')
    INSERT INTO #StandardTable( TableName) VALUES ('PutawayStrategy_DELLOG')
    INSERT INTO #StandardTable( TableName) VALUES ('PutawayStrategyDetail_DELLOG')
    INSERT INTO #StandardTable( TableName) VALUES ('Strategy_DELLOG')
    INSERT INTO #StandardTable( TableName) VALUES ('TTMStrategy_DELLOG')
    INSERT INTO #StandardTable( TableName) VALUES ('TTMStrategyDetail_DELLOG')
       
       

 
INSERT INTO #NonStandardTable
SELECT CAST(NAME AS NVARCHAR(40)) TableName, crDate as CreateDate
FROM   SYSOBJECTS OBJ 
WHERE obj.type = 'U' 
AND NAME NOT IN (SELECT TableName FROM #StandardTable)               
ORDER BY crDate

IF exists (Select 1 from #NonStandardTable)
BEGIN 
   DECLARE @tableHTML  NVARCHAR(MAX) ;
   SET @tableHTML =
       N'<H1>NON-EXceed Table in WMS DB Alert Notification</H1>' +
       N'<body><p align="left">Please remove all Non-EXceed table from WMS Database ASAP.<br><br></body>' +
       N'<table border="1">' +
       N'<tr><th>Table Name</th><th>Create Date</th></tr>' +
       CAST ( ( SELECT td = A.TableName, '', 
                       td = convert(char(50), A.CreateDate, 120), ''
                FROM #NonStandardTable A WITH (NOLOCK)
                ORDER BY 1, 2
         FOR XML PATH('tr'), TYPE 
       ) AS NVARCHAR(MAX) ) +
       N'</table>' ;
   
   
   EXEC msdb.dbo.sp_send_dbmail @recipients=@cRecipients,
       @subject = @csubject,
       @body = @tableHTML,
       @body_format = 'HTML' ;


END 

DROP TABLE #NonStandardTable
DROP TABLE #StandardTable

GO