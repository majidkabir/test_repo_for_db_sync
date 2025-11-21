SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: NspArchiveParameters                               */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC    [dbo].[NspArchiveParameters]
@c_copyfrom_db  NVARCHAR(55)
,              @c_copyto_db    NVARCHAR(55)
,              @b_Success      int        OUTPUT
,              @n_err          int        OUTPUT
,              @c_errmsg       NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
   @b_debug int            , -- Debug On Or Off
   @c_checkflag  NVARCHAR(1)   , -- Is the Do flag On(1) or Off(0)
   @n_retain_days int      , -- days to hold data
   @d_podate  datetime     , -- PO Date from PO header table
   @d_result  datetime     , -- date po_date - (getdate() - noofdaystoretain
   @n_testcount int        , -- cursor
   @n_rowcount  int        , -- cursor
   @c_tablename NVARCHAR(1)    ,  -- dummy variable
   @c_msg       NVARCHAR(255)
   /* #INCLUDE <SPARC1.SQL> */
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
   @b_debug = 0
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @n_cnt = count(*) FROM ArchiveParameters
      IF (@n_cnt > 1)
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err =  73201
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": ArchiveParameters has more the one row.
         (NspArchiveParameters)"
      END
      IF (@n_cnt = 0)
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err =  73201
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": ArchiveParameters no rows.(NspArchiveParameters)"
      END
   END
   SELECT  @c_checkflag = POActive  FROM ArchiveParameters
   IF (@b_debug = 1)
   BEGIN
      Select @c_checkflag , 'for POACTIVE'
      SELECT 'PONumberofDaysToRetain =', PONumberofDaysToRetain FROM ArchiveParameters
      SELECT 'POActive = ',POActive FROM ArchiveParameters                                                                 --no
      SELECT 'POStorerKeyStart = ', POStorerKeyStart FROM ArchiveParameters
      SELECT 'POStorerKeyEnd = ', POStorerKeyEnd FROM ArchiveParameters
      SELECT 'POStart = ', POStart FROM ArchiveParameters
      SELECT 'POEnd = ', POEnd FROM ArchiveParameters
      SELECT 'PODateType = ',PODateType  FROM ArchiveParameters
   END
   IF ( @c_checkflag =  'Y') and (@n_continue = 1 or @n_continue = 2)
   begin
      Exec nspArchivePO
      @c_copyfrom_db
      ,              @c_copyto_db
      ,              @b_Success
      ,              @n_err
      ,              @c_errmsg
   end
   SELECT @c_checkflag = ''
   SELECT  @c_checkflag = ShipActive FROM ArchiveParameters
   IF (@b_debug = 1)
   BEGIN
      Select @c_checkflag , 'for shipACTIVE'
      SELECT 'ShipNumberofDaysToRetain   =', ShipNumberofDaysToRetain FROM ArchiveParameters
      SELECT 'ShipActive                 =', ShipActive FROM ArchiveParameters
      SELECT 'ShipStorerKeyStart        =', ShipStorerKeyStart FROM ArchiveParameters
      SELECT 'ShipStorerKeyEnd          =', ShipStorerKeyEnd FROM ArchiveParameters
      SELECT 'ShipSysOrdStart           =', ShipSysOrdStart FROM ArchiveParameters
      SELECT 'ShipSysOrdEnd             =', ShipSysOrdEnd FROM ArchiveParameters
      SELECT 'ShipExternOrderKeyStart   =', ShipExternOrderKeyStart FROM ArchiveParameters
      SELECT 'ShipExternOrderKeyEnd     =', ShipExternOrderKeyEnd FROM ArchiveParameters
      SELECT 'ShipOrdTypStart           =', ShipOrdTypStart FROM ArchiveParameters
      SELECT 'ShipOrdTypEnd             =', ShipOrdTypEnd FROM ArchiveParameters
      SELECT 'ShipOrdGrpStart           =', ShipOrdGrpStart FROM ArchiveParameters
      SELECT 'ShipOrdGrpEnd             =', ShipOrdGrpEnd FROM ArchiveParameters
      SELECT 'ShipToStart               =', ShipToStart FROM ArchiveParameters
      SELECT 'ShipToEnd                 =', ShipToEnd FROM ArchiveParameters
      SELECT 'ShipBillToStart           =', ShipBillToStart FROM ArchiveParameters
      SELECT 'ShipBillToEnd             =', ShipBillToEnd FROM ArchiveParameters
      SELECT 'ShipmentOrderDateType          =', ShipmentOrderDateType FROM ArchiveParameters
   END
   IF ( @c_checkflag =  'Y') and (@n_continue = 1 or @n_continue = 2)
   begin
      Exec nspArchiveShippingOrder
      @c_copyfrom_db
      ,              @c_copyto_db
      ,              @b_Success
      ,              @n_err
      ,              @c_errmsg
   end
   SELECT @c_checkflag = ''
   SELECT  @c_checkflag = TranActive FROM ArchiveParameters
   IF (@b_debug = 1)
   BEGIN
      Select @c_checkflag , 'for TranACTIVE'
      SELECT 'TranNumberofDaysToRetain =', TranNumberofDaysToRetain FROM ArchiveParameters
      SELECT 'TranActive = ',TranActive FROM ArchiveParameters                                                                 --no
      SELECT 'TranStart = ', TranStart FROM ArchiveParameters
      SELECT 'TranEnd = ', TranEnd FROM ArchiveParameters
      SELECT 'TransferDateType = ',TransferDateType  FROM ArchiveParameters
   END
   IF ( @c_checkflag =  'Y') and (@n_continue = 1 or @n_continue = 2)
   begin
      Exec nspArchiveTransfer
      @c_copyfrom_db
      ,              @c_copyto_db
      ,              @b_Success
      ,              @n_err
      ,              @c_errmsg
   end
   SELECT @c_checkflag = ''
   SELECT  @c_checkflag = AdjActive FROM ArchiveParameters
   IF (@b_debug = 1)
   BEGIN
      Select @c_checkflag , 'for adjACTIVE'
      SELECT 'adjNumberofDaysToRetain =', adjNumberofDaysToRetain FROM ArchiveParameters
      SELECT 'adjActive = ',adjActive FROM ArchiveParameters                                                                 --no
      SELECT 'adjStart = ', adjStart FROM ArchiveParameters
      SELECT 'adjEnd = ', adjEnd FROM ArchiveParameters
      SELECT 'adjustmentDateType = ',adjustmentDateType  FROM ArchiveParameters
   END
   IF ( @c_checkflag =  'Y') and (@n_continue = 1 or @n_continue = 2)
   begin
      Exec nspArchiveAdjustment
      @c_copyfrom_db
      ,              @c_copyto_db
      ,              @b_Success
      ,              @n_err
      ,              @c_errmsg
   end
   /* START Add by DLIM for FBR27 20010622 */
   SELECT @c_checkflag = ''
   SELECT  @c_checkflag = CCActive FROM ArchiveParameters
   IF (@b_debug = 1)
   BEGIN
      Select @c_checkflag , 'for CCACTIVE'
      SELECT 'CCNumberofDaysToRetain =', CCNumberofDaysToRetain FROM ArchiveParameters
      SELECT 'CCActive = ',CCActive FROM ArchiveParameters                                                                 --no
      SELECT 'CCStart = ', CCStart FROM ArchiveParameters
      SELECT 'CCEnd = ', CCEnd FROM ArchiveParameters
      SELECT 'CCDateType = ',CCDateType  FROM ArchiveParameters
   END
   IF ( @c_checkflag =  'Y') and (@n_continue = 1 or @n_continue = 2)
   begin
      Exec nspArchiveCC
      @c_copyfrom_db
      ,              @c_copyto_db
      ,              @b_Success
      ,              @n_err
      ,              @c_errmsg
   end
   /* END Add by DLIM for FBR27 20010622 */
   SELECT @c_checkflag = ''
   SELECT  @c_checkflag = HAWBActive FROM ArchiveParameters
   IF (@b_debug = 1)
   BEGIN
      Select @c_checkflag , 'for hawbACTIVE'
      SELECT 'HAWBNumberofDaysToRetain =', HAWBNumberofDaysToRetain FROM ArchiveParameters
      SELECT 'HAWBActive = ',HAWBActive FROM ArchiveParameters                                                                 --no
      SELECT 'HAWBStart = ', HAWBStart FROM ArchiveParameters
      SELECT 'HAWBEnd = ', HAWBEnd FROM ArchiveParameters
      SELECT 'HAWBDateType = ',HAWBDateType  FROM ArchiveParameters
   END
   IF ( @c_checkflag =  'Y') and (@n_continue = 1 or @n_continue = 2)
   begin
      Exec nspArchiveHAWB
      @c_copyfrom_db
      ,              @c_copyto_db
      ,              @b_Success
      ,              @n_err
      ,              @c_errmsg
   end
   SELECT @c_checkflag = ''
   SELECT  @c_checkflag = MAWBActive FROM ArchiveParameters
   IF (@b_debug = 1)
   BEGIN
      Select @c_checkflag , 'for mawbACTIVE'
      SELECT 'mawbNumberofDaysToRetain =', mawbNumberofDaysToRetain FROM ArchiveParameters
      SELECT 'mawbActive = ',mawbActive FROM ArchiveParameters                                                                 --no
      SELECT 'mawbStart = ', mawbStart FROM ArchiveParameters
      SELECT 'mawbEnd = ', mawbEnd FROM ArchiveParameters
      SELECT 'mawbDateType = ',mawbDateType  FROM ArchiveParameters
   END
   IF ( @c_checkflag =  'Y') and (@n_continue = 1 or @n_continue = 2)
   begin
      Exec nspArchiveMAWB
      @c_copyfrom_db
      ,              @c_copyto_db
      ,              @b_Success
      ,              @n_err
      ,              @c_errmsg
   end
   SELECT @c_checkflag = ''
   SELECT  @c_checkflag = ReceiptActive FROM ArchiveParameters
   IF (@b_debug = 1)
   BEGIN
      Select @c_checkflag , 'for receiptACTIVE'
      SELECT 'receiptNumberofDaysToRetain =', receiptNumberofDaysToRetain FROM ArchiveParameters
      SELECT 'receiptActive = ',receiptActive FROM ArchiveParameters                                                                 --no
      SELECT 'receiptStorerKeyStart = ', receiptStorerKeyStart FROM ArchiveParameters
      SELECT 'receiptStorerKeyEnd = ', receiptStorerKeyEnd FROM ArchiveParameters
      SELECT 'receiptStart = ', receiptStart FROM ArchiveParameters
      SELECT 'receiptEnd = ', receiptEnd FROM ArchiveParameters
      SELECT 'receiptDateType = ',receiptDateType  FROM ArchiveParameters
   END
   IF ( @c_checkflag =  'Y') and (@n_continue = 1 or @n_continue = 2)
   begin
      Exec nspArchiveReceipt
      @c_copyfrom_db
      ,              @c_copyto_db
      ,              @b_Success
      ,              @n_err
      ,              @c_errmsg
   end
   SELECT  @c_checkflag = ITRNActive FROM ArchiveParameters
   IF (@b_debug = 1)
   BEGIN
      Select @c_checkflag , 'for itrnACTIVE'
      SELECT 'itrnNumberofDaysToRetain =', itrnNumberofDaysToRetain FROM ArchiveParameters
      SELECT 'itrnActive = ',itrnActive FROM ArchiveParameters                                                                 --no
      SELECT 'itrnStorerKeyStart = ', itrnStorerKeyStart FROM ArchiveParameters
      SELECT 'itrnStorerKeyEnd = ', itrnStorerKeyEnd FROM ArchiveParameters
      SELECT 'itrnSKUStart = ', itrnSkuStart FROM ArchiveParameters
      SELECT 'itrnSKUEnd = ', itrnSkuEnd FROM ArchiveParameters
      SELECT 'itrnLotStart = ', itrnLotStart FROM ArchiveParameters
      SELECT 'itrnLotEnd = ', itrnLotEnd FROM ArchiveParameters
      SELECT 'itrnDateType = ',itrnDateType  FROM ArchiveParameters
   END
   IF ( @c_checkflag =  'Y') and (@n_continue = 1 or @n_continue = 2)
   begin
      Exec nspArchiveInventory
      @c_copyfrom_db
      ,              @c_copyto_db
      ,              @b_Success
      ,              @n_err
      ,              @c_errmsg
   end
   SELECT @c_checkflag = ''
   SELECT  @c_checkflag = ContainerActive FROM ArchiveParameters
   IF (@b_debug = 1)
   BEGIN
      Select @c_checkflag , 'for containerACTIVE'
      SELECT 'containerNumberofDaysToRetain =', containerNumberofDaysToRetain FROM ArchiveParameters
      SELECT 'containerActive = ',containerActive FROM ArchiveParameters                                                                 --no
      SELECT 'containerStart = ', containerStart FROM ArchiveParameters
      SELECT 'containerEnd = ', containerEnd FROM ArchiveParameters
      SELECT 'containerDateType = ',containerDateType  FROM ArchiveParameters
   END
   IF ( @c_checkflag =  'Y') and (@n_continue = 1 or @n_continue = 2)
   begin
      Exec nspArchiveContainer
      @c_copyfrom_db
      ,              @c_copyto_db
      ,              @b_Success
      ,              @n_err
      ,              @c_errmsg
   end
   SELECT @c_checkflag = ''
   SELECT  @c_checkflag = PalletActive FROM ArchiveParameters
   IF (@b_debug = 1)
   BEGIN
      Select @c_checkflag , 'for palletACTIVE'
      SELECT 'palletNumberofDaysToRetain =', palletNumberofDaysToRetain FROM ArchiveParameters
      SELECT 'palletActive = ',palletActive FROM ArchiveParameters                                                                 --no
      SELECT 'palletStart = ', palletStart FROM ArchiveParameters
      SELECT 'palletEnd = ', palletEnd FROM ArchiveParameters
      SELECT 'palletsDateType = ',palletDateType  FROM ArchiveParameters
   END
   IF ( @c_checkflag =  'Y') and (@n_continue = 1 or @n_continue = 2)
   begin
      Exec nspArchivePallet
      @c_copyfrom_db
      ,              @c_copyto_db
      ,              @b_Success
      ,              @n_err
      ,              @c_errmsg
   end
   SELECT @c_checkflag = ''
   SELECT  @c_checkflag = CaseMActive FROM ArchiveParameters
   IF (@b_debug = 1)
   BEGIN
      Select @c_checkflag , 'for casemACTIVE'
      SELECT 'CaseMNumberofDaysToRetain =', CaseMNumberofDaysToRetain FROM ArchiveParameters
      SELECT 'CaseMActive = ',CaseMActive FROM ArchiveParameters                         --no
      SELECT 'CaseMStorerKeyStart = ', CaseMStorerKeyStart FROM ArchiveParameters
      SELECT 'CaseMStorerKeyEnd = ', CaseMStorerKeyEnd FROM ArchiveParameters
      SELECT 'CaseMStart = ', CaseMStart FROM ArchiveParameters
      SELECT 'CaseMEnd = ', CaseMEnd FROM ArchiveParameters
      SELECT 'CaseMDateType = ',CaseMDateType  FROM ArchiveParameters
   END
   IF ( @c_checkflag =  'Y') and (@n_continue = 1 or @n_continue = 2)
   begin
      Exec nspArchiveCASEMANIFEST
      @c_copyfrom_db
      ,              @c_copyto_db
      ,              @b_Success
      ,              @n_err
      ,              @c_errmsg
   end
   SELECT @c_checkflag = ''
   SELECT  @c_checkflag = MbolActive FROM ArchiveParameters
   IF (@b_debug = 1)
   BEGIN
      Select @c_checkflag , 'for mbolACTIVE'
      SELECT 'MBOLNumberofDaysToRetain =', MBOLNumberofDaysToRetain FROM ArchiveParameters
      SELECT 'MBOLActive = ',MBOLActive FROM ArchiveParameters
      SELECT 'MBOLStart = ', MBOLStart FROM ArchiveParameters
      SELECT 'MBOLEnd = ', MBOLEnd FROM ArchiveParameters                                                                      --no
      SELECT 'MBOLDepDateStart = ', MBOLDepDateStart FROM ArchiveParameters
      SELECT 'MBOLDepDateEnd = ', MBOLDepDateEnd FROM ArchiveParameters
      SELECT 'MBOLDelDateStart = ', MBOLDelDateStart FROM ArchiveParameters
      SELECT 'MBOLDelDateEnd = ', MBOLDelDateEnd FROM ArchiveParameters
      SELECT 'MBOLVoyageStart = ', MBOLVoyageStart FROM ArchiveParameters
      SELECT 'MBOLVoyageEnd = ', MBOLVoyageEnd FROM ArchiveParameters
      SELECT 'MBOLDateType = ',MBOLDateType  FROM ArchiveParameters
   END
   IF ( @c_checkflag =  'Y') and (@n_continue = 1 or @n_continue = 2)
   begin
      Exec nspArchiveMBOL
      @c_copyfrom_db
      ,              @c_copyto_db
      ,              @b_Success
      ,              @n_err
      ,              @c_errmsg
   end
   /* #INCLUDE <SPARC2.SQL> */
END


GO