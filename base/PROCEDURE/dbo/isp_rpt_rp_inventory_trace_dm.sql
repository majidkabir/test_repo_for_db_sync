SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_RP_INVENTORY_TRACE_DM                      */
/* Creation Date: 21-Jul-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-23091 - Philippines| Logi Report | Inventory Trace DM   */
/*                                                                      */
/* Called By: RPT_RP_INVENTORY_TRACE_DM                                 */
/*            Duplicate from isp_RPT_RP_INVENTORY_TRACE and modify      */
/*                                                                      */
/* Parameters: (Input)                                                  */
/*                                                                      */
/* PVCS Version: 1.0	                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver. Purposes                                 */
/* 21-Jul-2023  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_RPT_RP_INVENTORY_TRACE_DM]
   @dt_Date_Start       DATETIME
 , @dt_Date_End         DATETIME
 , @c_Facility_Start    NVARCHAR(5) = ''
 , @c_Facility_End      NVARCHAR(5)
 , @c_Storerkey_Start   NVARCHAR(15)
 , @c_Storerkey_End     NVARCHAR(15)
 , @c_Sku_Start         NVARCHAR(20)
 , @c_Sku_End           NVARCHAR(20)
 , @c_Style_Start       NVARCHAR(20)
 , @c_Style_End         NVARCHAR(20)
 , @c_Color_Start       NVARCHAR(10)
 , @c_Color_End         NVARCHAR(10)
 , @c_Size_Start        NVARCHAR(5)
 , @c_Size_End          NVARCHAR(5)
 , @c_Measurement_Start NVARCHAR(5)
 , @c_Measurement_End   NVARCHAR(5)
 , @c_Lot_Start         NVARCHAR(10)
 , @c_Lot_End           NVARCHAR(10)
 , @c_Loc_Start         NVARCHAR(10)
 , @c_Loc_End           NVARCHAR(10)
 , @c_Id_Start          NVARCHAR(18)
 , @c_Id_End            NVARCHAR(18)
 , @c_Lottable01_Start  NVARCHAR(18)
 , @c_Lottable01_End    NVARCHAR(18)
 , @c_Lottable02_Start  NVARCHAR(18)
 , @c_Lottable02_End    NVARCHAR(18)
 , @c_Lottable03_Start  NVARCHAR(18)
 , @c_Lottable03_End    NVARCHAR(18)
 , @c_Lottable04_Start  NVARCHAR(30)
 , @c_Lottable04_End    NVARCHAR(30)
 , @c_Lottable05_Start  NVARCHAR(30)
 , @c_Lottable05_End    NVARCHAR(30)
 , @c_Lottable06_Start  NVARCHAR(30)
 , @c_Lottable06_End    NVARCHAR(30)
 , @c_Lottable07_Start  NVARCHAR(30)
 , @c_Lottable07_End    NVARCHAR(30)
 , @c_Lottable08_Start  NVARCHAR(30)
 , @c_Lottable08_End    NVARCHAR(30)
 , @c_Lottable09_Start  NVARCHAR(30)
 , @c_Lottable09_End    NVARCHAR(30)
 , @c_Lottable10_Start  NVARCHAR(30)
 , @c_Lottable10_End    NVARCHAR(30)
 , @c_Lottable11_Start  NVARCHAR(30)
 , @c_Lottable11_End    NVARCHAR(30)
 , @c_Lottable12_Start  NVARCHAR(30)
 , @c_Lottable12_End    NVARCHAR(30)
 , @c_Lottable13_Start  NVARCHAR(30)
 , @c_Lottable13_End    NVARCHAR(30)
 , @c_Lottable14_Start  NVARCHAR(30)
 , @c_Lottable14_End    NVARCHAR(30)
 , @c_Lottable15_Start  NVARCHAR(30)
 , @c_Lottable15_End    NVARCHAR(30)
 , @c_Trantype          NVARCHAR(10)
 , @n_CutOffMonth       INT         = 12
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS ON
   SET ANSI_WARNINGS ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue            INT
         , @n_cnt                 INT
         , @n_rowid               INT
         , @c_sourcetype          NVARCHAR(30)
         , @c_sourcekey           NVARCHAR(20)
         , @c_sourcetypedesc      NVARCHAR(30)
         , @c_referencekey        NVARCHAR(30)
         , @c_externreferencekey  NVARCHAR(30)
         , @c_externreferencetype NVARCHAR(30)
         , @c_remarks             NVARCHAR(215)
         , @c_Trantype2           NVARCHAR(10)
         , @c_arcdbname           NVARCHAR(30)
         , @sql                   NVARCHAR(4000)
         , @c_SQLArgument         NVARCHAR(4000)
         , @c_DMdbname            NVARCHAR(250) = ''

   DECLARE @c_cnt1 INT = 0
   DECLARE @c_cnt2 INT = 0
   DECLARE @c_cnt3 INT = 0
   DECLARE @d_CutofDate DATETIME

   IF @n_CutOffMonth < 1
      SET @n_CutOffMonth = 3

   SET @d_CutofDate = DATEADD(MONTH, 0 - @n_CutOffMonth, GETDATE())

   SET @d_CutofDate = DATEADD(DAY, 1, EOMONTH(@d_CutofDate, -1))

   DECLARE @d_Trace_StartTime  DATETIME
         , @d_Trace_EndTime    DATETIME
         , @c_Trace_ModuleName NVARCHAR(20)
         , @d_Trace_Step1      DATETIME
         , @d_Trace_Step2      DATETIME
         , @d_Trace_Step3      DATETIME
         , @d_Trace_Step4      DATETIME
         , @d_Trace_Step5      DATETIME
         , @c_Trace_Step1      NVARCHAR(20)
         , @c_Trace_Step2      NVARCHAR(20)
         , @c_Trace_Step3      NVARCHAR(20)
         , @c_Trace_Step4      NVARCHAR(20)
         , @c_Trace_Step5      NVARCHAR(20)
         , @c_Trace_Col1       NVARCHAR(20)
         , @c_Trace_Col2       NVARCHAR(20)
         , @c_Trace_Col3       NVARCHAR(20)
         , @c_Trace_Col4       NVARCHAR(20)
         , @c_Trace_Col5       NVARCHAR(20)
         , @c_UserName         NVARCHAR(20)
         , @c_ExecArguments    NVARCHAR(4000)

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = N''
   SET @c_Trace_Col1 = N''
   SET @c_Trace_Col2 = N''
   SET @c_Trace_Col3 = N''
   SET @c_Trace_Col4 = N''
   SET @c_Trace_Col5 = N''

   IF ISNULL(@c_Facility_Start, '') = ''
   BEGIN
      SET @c_Facility_Start = ''
   END

   IF ISNULL(@c_Facility_End, '') = ''
   BEGIN
      SET @c_Facility_End = 'ZZZZZ'
   END

   IF ISNULL(@c_Storerkey_Start, '') = ''
   BEGIN
      SET @c_Storerkey_Start = ''
   END

   IF ISNULL(@c_Storerkey_End, '') = ''
   BEGIN
      SET @c_Storerkey_End = 'ZZZZZ'
   END

   IF ISNULL(@c_Sku_Start, '') = ''
   BEGIN
      SET @c_Sku_Start = ''
   END

   IF ISNULL(@c_Sku_End, '') = ''
   BEGIN
      SET @c_Sku_End = 'ZZZZZZZZZZZZZZZZZZZZ'
   END

   IF ISNULL(@c_Style_Start, '') = ''
   BEGIN
      SET @c_Style_Start = ''
   END

   IF ISNULL(@c_Style_End, '') = ''
   BEGIN
      SET @c_Style_End = 'ZZZZZZZZZZZZZZZZZZZZ'
   END

   IF ISNULL(@c_Color_Start, '') = ''
   BEGIN
      SET @c_Color_Start = ''
   END

   IF ISNULL(@c_Color_End, '') = ''
   BEGIN
      SET @c_Color_End = 'ZZZZZZZZZZZZZZZZZZZZ'
   END

   IF ISNULL(@c_Size_Start, '') = ''
   BEGIN
      SET @c_Size_Start = ''
   END

   IF ISNULL(@c_Size_End, '') = ''
   BEGIN
      SET @c_Size_End = 'ZZZZZZZZZZZZZZZZZZZZ'
   END

   IF ISNULL(@c_Measurement_Start, '') = ''
   BEGIN
      SET @c_Measurement_Start = ''
   END

   IF ISNULL(@c_Measurement_End, '') = ''
   BEGIN
      SET @c_Measurement_End = 'ZZZZZZZZZZZZZZZZZZZZ'
   END

   IF ISNULL(@c_Lot_Start, '') = ''
   BEGIN
      SET @c_Lot_Start = ''
   END

   IF ISNULL(@c_Lot_End, '') = ''
   BEGIN
      SET @c_Lot_End = 'ZZZZZZZZZZZZZZZZZZZZ'
   END

   IF ISNULL(@c_loc_Start, '') = ''
   BEGIN
      SET @c_Loc_Start = ''
   END

   IF ISNULL(@c_loc_End, '') = ''
   BEGIN
      SET @c_Loc_End = 'ZZZZZZZZZZZZZZZZZZZZ'
   END

   IF ISNULL(@c_Id_Start, '') = ''
   BEGIN
      SET @c_Id_Start = ''
   END

   IF ISNULL(@c_Id_End, '') = ''
   BEGIN
      SET @c_Id_End = 'ZZZZZZZZZZZZZZZZZZZZ'
   END

   IF ISNULL(@c_Lottable01_Start, '') = ''
   BEGIN
      SET @c_Lottable01_Start = ''
   END

   IF ISNULL(@c_Lottable01_End, '') = ''
   BEGIN
      SET @c_Lottable01_End = 'ZZZZZZZZZZZZZZZZZZ'
   END

   IF ISNULL(@c_Lottable02_Start, '') = ''
   BEGIN
      SET @c_Lottable02_Start = ''
   END

   IF ISNULL(@c_Lottable02_End, '') = ''
   BEGIN
      SET @c_Lottable02_End = 'ZZZZZZZZZZZZZZZZZZ'
   END

   IF ISNULL(@c_Lottable03_Start, '') = ''
   BEGIN
      SET @c_Lottable03_Start = ''
   END

   IF ISNULL(@c_Lottable03_End, '') = ''
   BEGIN
      SET @c_Lottable03_End = 'ZZZZZZZZZZZZZZZZZZ'
   END

   IF ISNULL(@c_Lottable04_Start, '') = ''
   BEGIN
      SET @c_Lottable04_Start = '1900-01-01'
   END

   IF ISNULL(@c_Lottable04_End, '') = ''
   BEGIN
      SET @c_Lottable04_End = '2099-01-01'
   END

   IF ISNULL(@c_Lottable05_Start, '') = ''
   BEGIN
      SET @c_Lottable05_Start = '1900-01-01'
   END

   IF ISNULL(@c_Lottable05_End, '') = ''
   BEGIN
      SET @c_Lottable05_End = '2099-01-01'
   END

   IF ISNULL(@c_Lottable06_Start, '') = ''
   BEGIN
      SET @c_Lottable06_Start = ''
   END

   IF ISNULL(@c_Lottable06_End, '') = ''
   BEGIN
      SET @c_Lottable06_End = 'ZZZZZZZZZZZZZZZZZZ'
   END

   IF ISNULL(@c_Lottable07_Start, '') = ''
   BEGIN
      SET @c_Lottable07_Start = ''
   END

   IF ISNULL(@c_Lottable07_End, '') = ''
   BEGIN
      SET @c_Lottable07_End = 'ZZZZZZZZZZZZZZZZZZ'
   END

   IF ISNULL(@c_Lottable08_Start, '') = ''
   BEGIN
      SET @c_Lottable08_Start = ''
   END

   IF ISNULL(@c_Lottable08_End, '') = ''
   BEGIN
      SET @c_Lottable08_End = 'ZZZZZZZZZZZZZZZZZZ'
   END

   IF ISNULL(@c_Lottable09_Start, '') = ''
   BEGIN
      SET @c_Lottable09_Start = ''
   END

   IF ISNULL(@c_Lottable09_End, '') = ''
   BEGIN
      SET @c_Lottable09_End = 'ZZZZZZZZZZZZZZZZZZ'
   END

   IF ISNULL(@c_Lottable10_Start, '') = ''
   BEGIN
      SET @c_Lottable10_Start = ''
   END

   IF ISNULL(@c_Lottable10_End, '') = ''
   BEGIN
      SET @c_Lottable10_End = 'ZZZZZZZZZZZZZZZZZZ'
   END

   IF ISNULL(@c_Lottable11_Start, '') = ''
   BEGIN
      SET @c_Lottable11_Start = ''
   END

   IF ISNULL(@c_Lottable11_End, '') = ''
   BEGIN
      SET @c_Lottable11_End = 'ZZZZZZZZZZZZZZZZZZ'
   END

   IF ISNULL(@c_Lottable12_Start, '') = ''
   BEGIN
      SET @c_Lottable12_Start = ''
   END

   IF ISNULL(@c_Lottable12_End, '') = ''
   BEGIN
      SET @c_Lottable12_End = 'ZZZZZZZZZZZZZZZZZZ'
   END

   IF ISNULL(@c_Lottable13_Start, '') = ''
   BEGIN
      SET @c_Lottable13_Start = '1900-01-01'
   END

   IF ISNULL(@c_Lottable13_End, '') = ''
   BEGIN
      SET @c_Lottable13_End = '2099-01-01'
   END

   IF ISNULL(@c_Lottable14_Start, '') = ''
   BEGIN
      SET @c_Lottable14_Start = '1900-01-01'
   END

   IF ISNULL(@c_Lottable14_End, '') = ''
   BEGIN
      SET @c_Lottable14_End = '2099-01-01'
   END

   IF ISNULL(@c_Lottable15_Start, '') = ''
   BEGIN
      SET @c_Lottable15_Start = '1900-01-01'
   END

   IF ISNULL(@c_Lottable15_End, '') = ''
   BEGIN
      SET @c_Lottable15_End = '2099-01-01'
   END

   SELECT @c_arcdbname = ISNULL(NSQLValue, '')
   FROM NSQLCONFIG (NOLOCK)
   WHERE ConfigKey = 'ArchiveDBName'

   CREATE TABLE #TMP_REF
   (
      ROWRef              INT           NOT NULL IDENTITY(1, 1) PRIMARY KEY
    , Referencekey        NVARCHAR(30)  NULL
    , ExternReferencekey  NVARCHAR(30)  NULL
    , ExternReferenceType NVARCHAR(30)  NULL
    , Remarks             NVARCHAR(215) NULL
   )

   CREATE TABLE #COMBINE_ITRN
   (
      storerkey     NVARCHAR(15)  NULL
    , effectivedate DATETIME      NULL
    , sourcetype    NVARCHAR(30)  NULL
    , trantype      NVARCHAR(10)  NULL
    , sku           NVARCHAR(20)  NULL
    , fromloc       NVARCHAR(10)  NULL
    , toloc         NVARCHAR(10)  NULL
    , fromid        NVARCHAR(18)  NULL
    , toid          NVARCHAR(18)  NULL
    , lot           NVARCHAR(10)  NULL
    , qty           INT           NULL
    , uom           NVARCHAR(10)  NULL
    , addwho        NVARCHAR(128) NULL
    , adddate       DATETIME      NULL
    , editwho       NVARCHAR(128) NULL
    , editdate      DATETIME      NULL
    , sourcekey     NVARCHAR(20)  NULL
    , itrnkey       NVARCHAR(10)  NULL
    , packkey       NVARCHAR(10)  NULL
    , uomqty        INT           NULL
    , ITRNstatus    NVARCHAR(10)  NULL
   )

   CREATE TABLE #TMP_ITRN
   (
      rowid               INT           NOT NULL IDENTITY(1, 1) PRIMARY KEY
    , storerkey           NVARCHAR(15)  NULL
    , Facility            NVARCHAR(5)   NULL
    , effectivedate       DATETIME      NULL
    , sourcetype          NVARCHAR(30)  NULL
    , trantype            NVARCHAR(10)  NULL
    , sku                 NVARCHAR(20)  NULL
    , fromloc             NVARCHAR(10)  NULL
    , toloc               NVARCHAR(10)  NULL
    , fromid              NVARCHAR(18)  NULL
    , toid                NVARCHAR(18)  NULL
    , lot                 NVARCHAR(10)  NULL
    , qty                 INT           NULL
    , caseqty             INT           NULL
    , ipqty               INT           NULL
    , uom                 NVARCHAR(10)  NULL
    , Lottable01          NVARCHAR(18)  NULL
    , Lottable02          NVARCHAR(18)  NULL
    , Lottable03          NVARCHAR(18)  NULL
    , Lottable04          DATETIME      NULL
    , Lottable05          DATETIME      NULL
    , Lottable06          NVARCHAR(30)  NULL
    , Lottable07          NVARCHAR(30)  NULL
    , Lottable08          NVARCHAR(30)  NULL
    , Lottable09          NVARCHAR(30)  NULL
    , Lottable10          NVARCHAR(30)  NULL
    , Lottable11          NVARCHAR(30)  NULL
    , Lottable12          NVARCHAR(30)  NULL
    , Lottable13          DATETIME      NULL
    , Lottable14          DATETIME      NULL
    , Lottable15          DATETIME      NULL
    , addwho              NVARCHAR(128) NULL
    , adddate             DATETIME      NULL
    , editwho             NVARCHAR(128) NULL
    , editdate            DATETIME      NULL
    , sourcekey           NVARCHAR(20)  NULL
    , SourceTypeDesc      NVARCHAR(30)  NULL
    , ReferenceKey        NVARCHAR(30)  NULL
    , ExternReferenceKey  NVARCHAR(30)  NULL
    , ExternReferenceType NVARCHAR(30)  NULL
    , Remarks             NVARCHAR(215) NULL
    , itrnkey             NVARCHAR(10)  NULL
    , descr               NVARCHAR(60)  NULL
    , style               NVARCHAR(20)  NULL
    , color               NVARCHAR(10)  NULL
    , size                NVARCHAR(10)  NULL
    , measurement         NVARCHAR(5)   NULL
    , packkey             NVARCHAR(10)  NULL
    , uomqty              INT           NULL
    , ITRNstatus          NVARCHAR(10)  NULL
   )

   SELECT @n_continue = 1

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @c_Trantype = 'Move'
      BEGIN
         SET @c_Trantype = 'MV'
      END
      ELSE IF @c_Trantype = 'Adjustment'
      BEGIN
         SET @c_Trantype = 'AJ'
      END
      ELSE IF @c_Trantype = 'Deposit'
      BEGIN
         SET @c_Trantype = 'DP'
      END
      ELSE IF @c_Trantype = 'Withdraw'
      BEGIN
         SET @c_Trantype = 'WD'
      END

      IF @c_Trantype = 'ALL'
      BEGIN
         INSERT INTO #COMBINE_ITRN
         SELECT ITRN.StorerKey
              , ITRN.AddDate
              , ITRN.SourceType
              , ITRN.TranType
              , ITRN.Sku
              , ITRN.FromLoc
              , ITRN.ToLoc
              , ITRN.FromID
              , ITRN.ToID
              , ITRN.Lot
              , ITRN.Qty
              , ITRN.UOM
              , ITRN.AddWho
              , ITRN.AddDate
              , ITRN.EditWho
              , ITRN.EditDate
              , ITRN.SourceKey
              , ITRN.ItrnKey
              , ITRN.PackKey
              , ITRN.UOMQty
              , ITRN.Status
         FROM ITRN (NOLOCK)
         WHERE (ITRN.StorerKey BETWEEN @c_Storerkey_Start AND @c_Storerkey_End)
         AND   (ITRN.Sku BETWEEN @c_Sku_Start AND @c_Sku_End)
         AND   (ITRN.Lot BETWEEN @c_Lot_Start AND @c_Lot_End)
         AND   ((ITRN.FromLoc BETWEEN @c_Loc_Start AND @c_Loc_End) OR (ITRN.ToLoc BETWEEN @c_Loc_Start AND @c_Loc_End))
         AND   ((ITRN.FromID BETWEEN @c_Id_Start AND @c_Id_End) OR (ITRN.ToID BETWEEN @c_Id_Start AND @c_Id_End))
         AND   (ITRN.AddDate BETWEEN @dt_Date_Start AND @dt_Date_End)
         AND   (ITRN.TranType IN ( 'WD', 'DP', 'AJ', 'MV' ))
         OPTION (RECOMPILE)

         SET @c_cnt2 = @@ROWCOUNT
      END
      ELSE
      BEGIN
         INSERT INTO #COMBINE_ITRN
         SELECT ITRN.StorerKey
              , ITRN.AddDate
              , ITRN.SourceType
              , ITRN.TranType
              , ITRN.Sku
              , ITRN.FromLoc
              , ITRN.ToLoc
              , ITRN.FromID
              , ITRN.ToID
              , ITRN.Lot
              , ITRN.Qty
              , ITRN.UOM
              , ITRN.AddWho
              , ITRN.AddDate
              , ITRN.EditWho
              , ITRN.EditDate
              , ITRN.SourceKey
              , ITRN.ItrnKey
              , ITRN.PackKey
              , ITRN.UOMQty
              , ITRN.Status
         FROM ITRN (NOLOCK)
         WHERE (ITRN.StorerKey BETWEEN @c_Storerkey_Start AND @c_Storerkey_End)
         AND   (ITRN.Sku BETWEEN @c_Sku_Start AND @c_Sku_End)
         AND   (ITRN.Lot BETWEEN @c_Lot_Start AND @c_Lot_End)
         AND   ((ITRN.FromLoc BETWEEN @c_Loc_Start AND @c_Loc_End) OR (ITRN.ToLoc BETWEEN @c_Loc_Start AND @c_Loc_End))
         AND   ((ITRN.FromID BETWEEN @c_Id_Start AND @c_Id_End) OR (ITRN.ToID BETWEEN @c_Id_Start AND @c_Id_End))
         AND   (ITRN.AddDate BETWEEN @dt_Date_Start AND @dt_Date_End)
         AND   (ITRN.TranType = @c_Trantype)
         OPTION (RECOMPILE)

         SET @c_cnt2 = @@ROWCOUNT
      END

      IF ISNULL(RTRIM(@c_arcdbname), '') <> ''
      BEGIN
         IF @c_Trantype = 'ALL'
         BEGIN
            SELECT @sql = N'INSERT INTO #COMBINE_ITRN '
                          + N' SELECT TOP 1000000 ITRN.Storerkey, ITRN.adddate, ITRN.SourceType, ITRN.Trantype, ITRN.Sku, '
                          + N'        ITRN.FromLoc, ITRN.ToLoc, ITRN.FromID, ITRN.ToID, ITRN.Lot, ITRN.Qty, ITRN.UOM, '
                          + N'        ITRN.AddWho, ITRN.AddDate, ITRN.EditWho, ITRN.EditDate, ITRN.Sourcekey, ITRN.Itrnkey, '
                          + N'        ITRN.PackKey, ITRN.UOMQty, ITRN.Status ' + N' FROM ' + RTRIM(@c_arcdbname)
                          + N'.dbo.ITRN ITRN (NOLOCK) ' + N' WHERE ( ITRN.adddate >=  @d_CutofDate )  '
                          + N' AND (ITRN.Storerkey BETWEEN RTRIM(@c_Storerkey_Start) AND RTRIM(@c_Storerkey_End) ) '
                          + N' AND (ITRN.Sku BETWEEN RTRIM(@c_Sku_Start)  AND RTRIM(@c_Sku_End) ) '
                          + N' AND (ITRN.Lot BETWEEN RTRIM(@c_Lot_Start)  AND  RTRIM(@c_Lot_End) )'
                          + N' AND ((ITRN.FromLoc BETWEEN RTRIM(@c_loc_Start)  AND  RTRIM(@c_loc_End) ) '
                          + N' OR (ITRN.ToLoc BETWEEN RTRIM(@c_loc_Start) AND RTRIM(@c_loc_End) )) '
                          + N' AND ((ITRN.FromID BETWEEN RTRIM(@c_Id_Start)  AND RTRIM(@c_Id_End) ) '
                          + N' OR (ITRN.ToID BETWEEN RTRIM(@c_Id_Start)  AND RTRIM(@c_Id_End) )) '
                          + N' AND (ITRN.Adddate BETWEEN @dt_Date_Start AND @dt_Date_End ) '
                          + N' AND (ITRN.Trantype IN (''WD'',''DP'',''AJ'',''MV'')) ' + N' ORDER BY ITRN.adddate DESC '
                          + N' OPTION(RECOMPILE) '

            SET @c_SQLArgument = N''
            SET @c_SQLArgument = N'@c_Storerkey_Start nvarchar(15) ' + N', @c_Storerkey_End nvarchar(15) '
                                 + N', @c_Sku_Start nvarchar(20) ' + N', @c_Sku_End nvarchar(20) '
                                 + N', @c_Lot_Start nvarchar(10) ' + N', @c_Lot_End nvarchar(10) '
                                 + N', @c_Loc_Start nvarchar(10) ' + N', @c_Loc_End nvarchar(10) '
                                 + N', @c_Id_Start nvarchar(18) ' + N', @c_Id_End nvarchar(18) '
                                 + N', @dt_Date_Start datetime ' + N', @dt_Date_End datetime '
                                 + N', @d_CutofDate datetime '

            EXEC sp_executesql @sql
                             , @c_SQLArgument
                             , @c_Storerkey_Start
                             , @c_Storerkey_End
                             , @c_Sku_Start
                             , @c_Sku_End
                             , @c_Lot_Start
                             , @c_Lot_End
                             , @c_Loc_Start
                             , @c_Loc_End
                             , @c_Id_Start
                             , @c_Id_End
                             , @dt_Date_Start
                             , @dt_Date_End
                             , @d_CutofDate

            SET @c_cnt2 = @@ROWCOUNT
         END
         ELSE
         BEGIN
            SELECT @sql = N'INSERT INTO #COMBINE_ITRN '
                          + N' SELECT TOP 1000000 ITRN.Storerkey, ITRN.adddate, ITRN.SourceType, ITRN.Trantype, ITRN.Sku, '
                          + N'        ITRN.FromLoc, ITRN.ToLoc, ITRN.FromID, ITRN.ToID, ITRN.Lot, ITRN.Qty, ITRN.UOM, '
                          + N'        ITRN.AddWho, ITRN.AddDate, ITRN.EditWho, ITRN.EditDate, ITRN.Sourcekey, ITRN.Itrnkey, '
                          + N'        ITRN.PackKey, ITRN.UOMQty, ITRN.Status ' + N' FROM ' + RTRIM(@c_arcdbname)
                          + N'.dbo.ITRN ITRN (NOLOCK) ' + N' WHERE ( ITRN.adddate >=  @d_CutofDate )  '
                          + N' AND (ITRN.Storerkey BETWEEN RTRIM(@c_Storerkey_Start) AND RTRIM(@c_Storerkey_End) ) '
                          + N' AND (ITRN.Sku BETWEEN RTRIM(@c_Sku_Start)  AND RTRIM(@c_Sku_End) ) '
                          + N' AND (ITRN.Lot BETWEEN RTRIM(@c_Lot_Start)  AND  RTRIM(@c_Lot_End) )'
                          + N' AND ((ITRN.FromLoc BETWEEN RTRIM(@c_loc_Start)  AND  RTRIM(@c_loc_End) ) '
                          + N' OR (ITRN.ToLoc BETWEEN RTRIM(@c_loc_Start) AND RTRIM(@c_loc_End) )) '
                          + N' AND ((ITRN.FromID BETWEEN RTRIM(@c_Id_Start)  AND RTRIM(@c_Id_End) ) '
                          + N' OR (ITRN.ToID BETWEEN RTRIM(@c_Id_Start)  AND RTRIM(@c_Id_End) )) '
                          + N' AND (ITRN.Adddate BETWEEN @dt_Date_Start AND @dt_Date_End ) '
                          + N' AND (ITRN.Trantype = RTRIM(@c_Trantype) ) ' + N' ORDER BY ITRN.adddate DESC '
                          + N' OPTION(RECOMPILE) '

            SET @c_SQLArgument = N''
            SET @c_SQLArgument = N'@c_Storerkey_Start nvarchar(15) ' + N', @c_Storerkey_End nvarchar(15) '
                                 + N', @c_Sku_Start nvarchar(20) ' + N', @c_Sku_End nvarchar(20) '
                                 + N', @c_Lot_Start nvarchar(10) ' + N', @c_Lot_End nvarchar(10) '
                                 + N', @c_Loc_Start nvarchar(10) ' + N', @c_Loc_End nvarchar(10) '
                                 + N', @c_Id_Start nvarchar(18) ' + N', @c_Id_End nvarchar(18) '
                                 + N', @dt_Date_Start datetime ' + N', @dt_Date_End datetime '
                                 + N', @c_Trantype nvarchar(18) ' + N', @d_CutofDate datetime '

            EXEC sp_executesql @sql
                             , @c_SQLArgument
                             , @c_Storerkey_Start
                             , @c_Storerkey_End
                             , @c_Sku_Start
                             , @c_Sku_End
                             , @c_Lot_Start
                             , @c_Lot_End
                             , @c_Loc_Start
                             , @c_Loc_End
                             , @c_Id_Start
                             , @c_Id_End
                             , @dt_Date_Start
                             , @dt_Date_End
                             , @c_Trantype
                             , @d_CutofDate
            SET @c_cnt2 = @@ROWCOUNT
         END
      END

      SELECT @c_DMdbname = ISNULL(NSQLDescrip,'') 
      FROM NSQLCONFIG (NOLOCK)     
      WHERE ConfigKey='DataMartServerDBName'

      IF ISNULL(RTRIM(@c_DMdbname), '') <> ''
      BEGIN
         IF @c_Trantype = 'ALL'
         BEGIN
            SELECT @sql = N'INSERT INTO #COMBINE_ITRN '
                          + N' SELECT TOP 1000000 ITRN.Storerkey, ITRN.adddate, ITRN.SourceType, ITRN.Trantype, ITRN.Sku, '
                          + N'        ITRN.FromLoc, ITRN.ToLoc, ITRN.FromID, ITRN.ToID, ITRN.Lot, ITRN.Qty, ITRN.UOM, '
                          + N'        ITRN.AddWho, ITRN.AddDate, ITRN.EditWho, ITRN.EditDate, ITRN.Sourcekey, ITRN.Itrnkey, '
                          + N'        ITRN.PackKey, ITRN.UOMQty, ITRN.Status ' 
                          + N' FROM ' + RTRIM(@c_DMdbname) + N'.ODS.ITRN ITRN (NOLOCK) ' 
                          + N' WHERE ( ITRN.adddate >=  @d_CutofDate )  '
                          + N' AND (ITRN.Storerkey BETWEEN RTRIM(@c_Storerkey_Start) AND RTRIM(@c_Storerkey_End) ) '
                          + N' AND (ITRN.Sku BETWEEN RTRIM(@c_Sku_Start) AND RTRIM(@c_Sku_End) ) '
                          + N' AND (ITRN.Lot BETWEEN RTRIM(@c_Lot_Start) AND RTRIM(@c_Lot_End) )'
                          + N' AND ((ITRN.FromLoc BETWEEN RTRIM(@c_loc_Start) AND RTRIM(@c_loc_End) ) '
                          + N' OR (ITRN.ToLoc BETWEEN RTRIM(@c_loc_Start) AND RTRIM(@c_loc_End) )) '
                          + N' AND ((ITRN.FromID BETWEEN RTRIM(@c_Id_Start) AND RTRIM(@c_Id_End) ) '
                          + N' OR (ITRN.ToID BETWEEN RTRIM(@c_Id_Start)  AND RTRIM(@c_Id_End) )) '
                          + N' AND (ITRN.Adddate BETWEEN @dt_Date_Start AND @dt_Date_End ) '
                          + N' AND (ITRN.Trantype IN (''WD'',''DP'',''AJ'',''MV'')) ' 
                          + N' AND NOT EXISTS (SELECT 1 FROM #COMBINE_ITRN C (NOLOCK) WHERE C.ITRNKEY = ITRN.ITRNKEY) '
                          + N' ORDER BY ITRN.adddate DESC '
                          + N' OPTION(RECOMPILE) '

            SET @c_SQLArgument = N''
            SET @c_SQLArgument = N'  @c_Storerkey_Start NVARCHAR(15) '
                               + N', @c_Storerkey_End   NVARCHAR(15) '
                               + N', @c_Sku_Start       NVARCHAR(20) '
                               + N', @c_Sku_End         NVARCHAR(20) '
                               + N', @c_Lot_Start       NVARCHAR(10) '
                               + N', @c_Lot_End         NVARCHAR(10) '
                               + N', @c_Loc_Start       NVARCHAR(10) '
                               + N', @c_Loc_End         NVARCHAR(10) '
                               + N', @c_Id_Start        NVARCHAR(18) '
                               + N', @c_Id_End          NVARCHAR(18) '
                               + N', @dt_Date_Start     DATETIME     '
                               + N', @dt_Date_End       DATETIME     '
                               + N', @d_CutofDate       DATETIME     '

            EXEC sp_executesql @sql
                             , @c_SQLArgument
                             , @c_Storerkey_Start
                             , @c_Storerkey_End
                             , @c_Sku_Start
                             , @c_Sku_End
                             , @c_Lot_Start
                             , @c_Lot_End
                             , @c_Loc_Start
                             , @c_Loc_End
                             , @c_Id_Start
                             , @c_Id_End
                             , @dt_Date_Start
                             , @dt_Date_End
                             , @d_CutofDate

            SET @c_cnt2 = @@ROWCOUNT
         END
         ELSE
         BEGIN
            SELECT @sql = N'INSERT INTO #COMBINE_ITRN '
                          + N' SELECT TOP 1000000 ITRN.Storerkey, ITRN.adddate, ITRN.SourceType, ITRN.Trantype, ITRN.Sku, '
                          + N'        ITRN.FromLoc, ITRN.ToLoc, ITRN.FromID, ITRN.ToID, ITRN.Lot, ITRN.Qty, ITRN.UOM, '
                          + N'        ITRN.AddWho, ITRN.AddDate, ITRN.EditWho, ITRN.EditDate, ITRN.Sourcekey, ITRN.Itrnkey, '
                          + N'        ITRN.PackKey, ITRN.UOMQty, ITRN.Status ' 
                          + N' FROM ' + RTRIM(@c_DMdbname) + N'.ODS.ITRN ITRN (NOLOCK) ' 
                          + N' WHERE ( ITRN.adddate >=  @d_CutofDate )  '
                          + N' AND (ITRN.Storerkey BETWEEN RTRIM(@c_Storerkey_Start) AND RTRIM(@c_Storerkey_End) ) '
                          + N' AND (ITRN.Sku BETWEEN RTRIM(@c_Sku_Start) AND RTRIM(@c_Sku_End) ) '
                          + N' AND (ITRN.Lot BETWEEN RTRIM(@c_Lot_Start) AND RTRIM(@c_Lot_End) )'
                          + N' AND ((ITRN.FromLoc BETWEEN RTRIM(@c_loc_Start) AND RTRIM(@c_loc_End) ) '
                          + N' OR (ITRN.ToLoc BETWEEN RTRIM(@c_loc_Start) AND RTRIM(@c_loc_End) )) '
                          + N' AND ((ITRN.FromID BETWEEN RTRIM(@c_Id_Start) AND RTRIM(@c_Id_End) ) '
                          + N' OR (ITRN.ToID BETWEEN RTRIM(@c_Id_Start)  AND RTRIM(@c_Id_End) )) '
                          + N' AND (ITRN.Adddate BETWEEN @dt_Date_Start AND @dt_Date_End ) '
                          + N' AND (ITRN.Trantype = RTRIM(@c_Trantype) ) ' 
                          + N' AND NOT EXISTS (SELECT 1 FROM #COMBINE_ITRN C (NOLOCK) WHERE C.ITRNKEY = ITRN.ITRNKEY) '
                          + N' ORDER BY ITRN.adddate DESC '
                          + N' OPTION(RECOMPILE) '

            SET @c_SQLArgument = N''
            SET @c_SQLArgument = N'  @c_Storerkey_Start NVARCHAR(15) '
                               + N', @c_Storerkey_End   NVARCHAR(15) '
                               + N', @c_Sku_Start       NVARCHAR(20) '
                               + N', @c_Sku_End         NVARCHAR(20) '
                               + N', @c_Lot_Start       NVARCHAR(10) '
                               + N', @c_Lot_End         NVARCHAR(10) '
                               + N', @c_Loc_Start       NVARCHAR(10) '
                               + N', @c_Loc_End         NVARCHAR(10) '
                               + N', @c_Id_Start        NVARCHAR(18) '
                               + N', @c_Id_End          NVARCHAR(18) '
                               + N', @dt_Date_Start     DATETIME     '
                               + N', @dt_Date_End       DATETIME     '
                               + N', @d_CutofDate       DATETIME     '

            EXEC sp_executesql @sql
                             , @c_SQLArgument
                             , @c_Storerkey_Start
                             , @c_Storerkey_End
                             , @c_Sku_Start
                             , @c_Sku_End
                             , @c_Lot_Start
                             , @c_Lot_End
                             , @c_Loc_Start
                             , @c_Loc_End
                             , @c_Id_Start
                             , @c_Id_End
                             , @dt_Date_Start
                             , @dt_Date_End
                             , @c_Trantype
                             , @d_CutofDate
            SET @c_cnt2 = @@ROWCOUNT
         END
      END

      SET @d_Trace_Step2 = GETDATE()

      SET @c_Trace_Col1 = CAST(@c_cnt1 AS VARCHAR)
      SET @c_Trace_Col2 = CAST(@c_cnt2 AS VARCHAR)

      INSERT INTO #TMP_ITRN (storerkey, Facility, effectivedate, sourcetype --4
                           , trantype, sku, fromloc, toloc, fromid --9
                           , toid, lot, qty, caseqty, ipqty --14
                           , uom, Lottable01, Lottable02, Lottable03, Lottable04 --19
                           , Lottable05, Lottable06, Lottable07, Lottable08, Lottable09 --24
                           , Lottable10, Lottable11, Lottable12, Lottable13, Lottable14 --29
                           , Lottable15, addwho, adddate, editwho, editdate --34
                           , sourcekey, SourceTypeDesc, ReferenceKey, ExternReferenceKey, ExternReferenceType --39
                           , Remarks, itrnkey, descr, style, color --44                             
                           , size, measurement, packkey, uomqty, ITRNstatus) --49           
      SELECT TOP 1000000 ITRN.storerkey
                       , LOC.Facility
                       , ITRN.adddate AS Effectivedate
                       , ITRN.sourcetype
                       , ITRN.trantype --5
                       , ITRN.sku
                       , ITRN.fromloc
                       , ITRN.toloc
                       , ITRN.fromid
                       , ITRN.toid
                       , ITRN.lot
                       , ITRN.qty --12
                       , CASE WHEN PACK.CaseCnt > 0 THEN FLOOR(ITRN.qty / PACK.CaseCnt)
                              ELSE 0 END AS caseqty --13
                       , CASE WHEN PACK.InnerPack > 0 THEN FLOOR(ITRN.qty / PACK.InnerPack)
                              ELSE 0 END AS ipqty --14
                       , ITRN.uom
                       , LA.Lottable01
                       , LA.Lottable02
                       , LA.Lottable03
                       , LA.Lottable04
                       , LA.Lottable05 --20
                       , LA.Lottable06
                       , LA.Lottable07
                       , LA.Lottable08
                       , LA.Lottable09
                       , LA.Lottable10 --25             
                       , LA.Lottable11
                       , LA.Lottable12
                       , LA.Lottable13
                       , LA.Lottable14
                       , LA.Lottable15 --30              
                       , ITRN.addwho
                       , ITRN.adddate
                       , ITRN.editwho
                       , ITRN.editdate
                       , ITRN.sourcekey --35
                       , CONVERT(NVARCHAR(30), '') AS SourceTypeDesc
                       , CONVERT(NVARCHAR(30), '') AS ReferenceKey --37
                       , CONVERT(NVARCHAR(30), '') AS ExternReferenceKey
                       , CONVERT(NVARCHAR(30), '') AS ExternReferenceType --39
                       , CONVERT(NVARCHAR(215), '') AS Remarks
                       , ITRN.itrnkey
                       , SKU.DESCR
                       , SKU.Style
                       , SKU.Color --44        
                       , SKU.Size
                       , SKU.Measurement
                       , ITRN.packkey
                       , ITRN.uomqty
                       , ITRN.ITRNstatus -- 49                                    
      FROM #COMBINE_ITRN ITRN
      JOIN LOC (NOLOCK) ON (ITRN.toloc = LOC.Loc)
      JOIN LOTATTRIBUTE LA (NOLOCK) ON (ITRN.lot = LA.Lot)
      JOIN SKU (NOLOCK) ON (ITRN.storerkey = SKU.StorerKey AND ITRN.sku = SKU.Sku)
      JOIN PACK (NOLOCK) ON (SKU.PACKKey = PACK.PackKey)
      WHERE ITRN.adddate >= @d_CutofDate
      AND   (LOC.Facility BETWEEN @c_Facility_Start AND @c_Facility_End)
      AND   (ISNULL(SKU.Style, '') BETWEEN @c_Style_Start AND @c_Style_End)
      AND   (ISNULL(SKU.Color, '') BETWEEN @c_Color_Start AND @c_Color_End)
      AND   (ISNULL(SKU.Size, '') BETWEEN @c_Size_Start AND @c_Size_End)
      AND   (ISNULL(SKU.Measurement, '') BETWEEN @c_Measurement_Start AND @c_Measurement_End)
      AND   (ISNULL(LA.Lottable01, '') BETWEEN @c_Lottable01_Start AND @c_Lottable01_End)
      AND   (ISNULL(LA.Lottable02, '') BETWEEN @c_Lottable02_Start AND @c_Lottable02_End)
      AND   (ISNULL(LA.Lottable03, '') BETWEEN @c_Lottable03_Start AND @c_Lottable03_End)
      AND   (CONVERT(NVARCHAR(20), ISNULL(LA.Lottable04, ' '), 120) BETWEEN CONVERT(NVARCHAR(20), CONVERT(DATETIME, @c_Lottable04_Start), 120) AND CONVERT(NVARCHAR(20), CONVERT(DATETIME, @c_Lottable04_End), 120))
      AND   (CONVERT(NVARCHAR(20), ISNULL(LA.Lottable05, ' '), 120) BETWEEN CONVERT(NVARCHAR(20), CONVERT(DATETIME, @c_Lottable05_Start), 120) AND CONVERT(NVARCHAR(20), CONVERT(DATETIME, @c_Lottable05_End), 120))
      AND   (ISNULL(LA.Lottable06, '') BETWEEN @c_Lottable06_Start AND @c_Lottable06_End)
      AND   (ISNULL(LA.Lottable07, '') BETWEEN @c_Lottable07_Start AND @c_Lottable07_End)
      AND   (ISNULL(LA.Lottable08, '') BETWEEN @c_Lottable08_Start AND @c_Lottable08_End)
      AND   (ISNULL(LA.Lottable09, '') BETWEEN @c_Lottable09_Start AND @c_Lottable09_End)
      AND   (ISNULL(LA.Lottable10, '') BETWEEN @c_Lottable10_Start AND @c_Lottable10_End)
      AND   (ISNULL(LA.Lottable11, '') BETWEEN @c_Lottable11_Start AND @c_Lottable11_End)
      AND   (ISNULL(LA.Lottable12, '') BETWEEN @c_Lottable12_Start AND @c_Lottable12_End)
      AND   (CONVERT(NVARCHAR(20), ISNULL(LA.Lottable13, ' '), 120) BETWEEN CONVERT(NVARCHAR(20), CONVERT(DATETIME, @c_Lottable13_Start), 120) AND CONVERT(NVARCHAR(20), CONVERT(DATETIME, @c_Lottable13_End), 120))
      AND   (CONVERT(NVARCHAR(20), ISNULL(LA.Lottable14, ' '), 120) BETWEEN CONVERT(NVARCHAR(20), CONVERT(DATETIME, @c_Lottable14_Start), 120) AND CONVERT(NVARCHAR(20), CONVERT(DATETIME, @c_Lottable14_End), 120))
      AND   (CONVERT(NVARCHAR(20), ISNULL(LA.Lottable15, ' '), 120) BETWEEN CONVERT(NVARCHAR(20), CONVERT(DATETIME, @c_Lottable15_Start), 120) AND CONVERT(NVARCHAR(20), CONVERT(DATETIME, @c_Lottable15_End), 120))
      ORDER BY ITRN.adddate DESC
             , ITRN.itrnkey DESC

      SET @c_cnt3 = @@ROWCOUNT

      SELECT @n_rowid = 0

      TRUNCATE TABLE #COMBINE_ITRN

      IF OBJECT_ID('tempdb..#COMBINE_ITRN') IS NOT NULL
         DROP TABLE #COMBINE_ITRN

      SET @d_Trace_Step3 = GETDATE()
      SET @c_Trace_Col3 = CAST(@c_cnt3 AS VARCHAR)
      SET @c_Trace_Col4 = SUSER_SNAME()

      DECLARE C_ItemLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT rowid
           , sourcekey
           , ISNULL(sourcetype, '')
           , trantype
      FROM #TMP_ITRN
      ORDER BY rowid DESC

      OPEN C_ItemLoop
      FETCH NEXT FROM C_ItemLoop
      INTO @n_rowid
         , @c_sourcekey
         , @c_sourcetype
         , @c_Trantype2
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SELECT @c_sourcetypedesc = @c_sourcetype
              , @c_referencekey = @c_sourcekey
              , @c_externreferencekey = N''
              , @c_externreferencetype = N''
              , @c_remarks = N''

         IF @c_Trantype2 = 'MV'
         BEGIN
            SET @c_sourcetypedesc = N'Inventory Move'
         END

         IF @c_sourcetype = 'ntrPickDetailUpdate'
         BEGIN
            SET @c_sourcetypedesc = N'Orders'

            TRUNCATE TABLE #TMP_REF

            INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType, Remarks)
            SELECT ORDERS.OrderKey
                 , ORDERS.ExternOrderKey
                 , ORDERS.Type
                 , ORDERS.C_Company
            FROM PICKDETAIL (NOLOCK)
            JOIN ORDERS (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERS.OrderKey)
            WHERE PICKDETAIL.PickDetailKey = LEFT(@c_sourcekey, 10)

            IF ISNULL(RTRIM(@c_arcdbname), '') <> '' AND @@ROWCOUNT = 0
            BEGIN
               SELECT @sql = N'INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks) '
                             + +N' SELECT ORDERS.Orderkey, ORDERS.ExternOrderkey, '
                             + N'        ORDERS.Type, ORDERS.c_company ' + N' FROM ' + RTRIM(@c_arcdbname)
                             + N'.dbo.PICKDETAIL PICKDETAIL (NOLOCK) ' + N' JOIN ' + RTRIM(@c_arcdbname)
                             + N'.dbo.ORDERS ORDERS (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERS.Orderkey) '
                             + N' WHERE PICKDETAIL.Pickdetailkey = LEFT(@c_sourcekey,10) '

               SET @c_SQLArgument = N''
               SET @c_SQLArgument = N'@c_sourcekey nvarchar(20) '

               EXEC sp_executesql @sql, @c_SQLArgument, @c_sourcekey
            END

            SELECT TOP 1 @c_referencekey = Referencekey
                       , @c_externreferencekey = ExternReferencekey
                       , @c_externreferencetype = ExternReferenceType
                       , @c_remarks = Remarks
            FROM #TMP_REF
         END

         IF @c_sourcetype = 'ntrReceiptDetailUpdate' OR @c_sourcetype = 'ntrReceiptDetailAdd'
         BEGIN
            SET @c_sourcetypedesc = N'Receipt'

            TRUNCATE TABLE #TMP_REF

            INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType, Remarks)
            SELECT RECEIPT.ReceiptKey
                 , RECEIPT.ExternReceiptKey
                 , RECEIPT.RECType
                 , CONVERT(NVARCHAR(215), RECEIPT.Notes)
            FROM RECEIPT (NOLOCK)
            WHERE RECEIPT.ReceiptKey = LEFT(@c_sourcekey, 10)

            IF ISNULL(RTRIM(@c_arcdbname), '') <> '' AND @@ROWCOUNT = 0
            BEGIN
               SELECT @sql = N'INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks) '
                             + +N' SELECT RECEIPT.Receiptkey, RECEIPT.ExternReceiptkey, '
                             + N'        RECEIPT.RecType, CONVERT(NVARCHAR(215),RECEIPT.Notes) ' + N' FROM '
                             + RTRIM(@c_arcdbname) + N'.dbo.RECEIPT RECEIPT (NOLOCK) '
                             + N' WHERE RECEIPT.Receiptkey = LEFT(@c_sourcekey,10) '

               SET @c_SQLArgument = N''
               SET @c_SQLArgument = N'@c_sourcekey nvarchar(20) '

               EXEC sp_executesql @sql, @c_SQLArgument, @c_sourcekey
            END

            SELECT TOP 1 @c_referencekey = Referencekey
                       , @c_externreferencekey = ExternReferencekey
                       , @c_externreferencetype = ExternReferenceType
                       , @c_remarks = Remarks
            FROM #TMP_REF
         END

         IF @c_sourcetype = 'ntrAdjustmentDetailUpdate' OR @c_sourcetype = 'ntrAdjustmentDetailAdd'
         BEGIN
            SET @c_sourcetypedesc = N'Adjustment'

            TRUNCATE TABLE #TMP_REF

            INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType, Remarks)
            SELECT ADJUSTMENT.AdjustmentKey
                 , ADJUSTMENT.CustomerRefNo
                 , ADJUSTMENT.AdjustmentType
                 , CONVERT(NVARCHAR(215), ADJUSTMENT.Remarks)
            FROM ADJUSTMENT (NOLOCK)
            WHERE ADJUSTMENT.AdjustmentKey = LEFT(@c_sourcekey, 10)

            IF ISNULL(RTRIM(@c_arcdbname), '') <> '' AND @@ROWCOUNT = 0
            BEGIN
               SELECT @sql = N'INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks) '
                             + +N' SELECT ADJUSTMENT.Adjustmentkey, ADJUSTMENT.CustomerRefNo, '
                             + N'        ADJUSTMENT.AdjustmentType, CONVERT(NVARCHAR(215),ADJUSTMENT.Remarks) '
                             + N' FROM ' + RTRIM(@c_arcdbname) + N'.dbo.ADJUSTMENT ADJUSTMENT (NOLOCK) '
                             + N' WHERE ADJUSTMENT.Adjustmentkey = LEFT(@c_sourcekey,10) '

               SET @c_SQLArgument = N''
               SET @c_SQLArgument = N'@c_sourcekey nvarchar(20) '

               EXEC sp_executesql @sql, @c_SQLArgument, @c_sourcekey
            END

            SELECT TOP 1 @c_referencekey = Referencekey
                       , @c_externreferencekey = ExternReferencekey
                       , @c_externreferencetype = ExternReferenceType
                       , @c_remarks = Remarks
            FROM #TMP_REF
         END

         IF @c_sourcetype = 'ntrReplenishmentUpdate'
         BEGIN
            SET @c_sourcetypedesc = N'Replenishment'
         END

         IF @c_sourcetype = 'WSPUTAWAY'
         BEGIN
            SET @c_sourcetypedesc = N'Put-Away'
         END

         IF @c_sourcetype = 'ntrTransferDetailUpdate'
         BEGIN
            SET @c_sourcetypedesc = N'Transfer'

            TRUNCATE TABLE #TMP_REF

            INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType, Remarks)
            SELECT TRANSFER.TransferKey
                 , TRANSFER.CustomerRefNo
                 , TRANSFER.Type
                 , CONVERT(NVARCHAR(215), TRANSFER.Remarks)
            FROM dbo.TRANSFER (NOLOCK)
            WHERE TRANSFER.TransferKey = LEFT(@c_sourcekey, 10)

            IF ISNULL(RTRIM(@c_arcdbname), '') <> '' AND @@ROWCOUNT = 0
            BEGIN
               SELECT @sql = N'INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks) '
                             + +N' SELECT TRANSFER.Transferkey, TRANSFER.CustomerRefNo, '
                             + N'        TRANSFER.Type, CONVERT(NVARCHAR(215),TRANSFER.Remarks) ' + N' FROM '
                             + RTRIM(@c_arcdbname) + N'.dbo.TRANSFER TRANSFER (NOLOCK) '
                             + N' WHERE TRANSFER.Transferkey = LEFT(@c_sourcekey,10) '

               SET @c_SQLArgument = N''
               SET @c_SQLArgument = N'@c_sourcekey nvarchar(20) '

               EXEC sp_executesql @sql, @c_SQLArgument, @c_sourcekey
            END

            SELECT TOP 1 @c_referencekey = Referencekey
                       , @c_externreferencekey = ExternReferencekey
                       , @c_externreferencetype = ExternReferenceType
                       , @c_remarks = Remarks
            FROM #TMP_REF
         END

         IF @c_sourcetype = 'ntrInventoryQCDetailUpdate'
         BEGIN
            SET @c_sourcetypedesc = N'IQC'

            TRUNCATE TABLE #TMP_REF

            INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType, Remarks)
            SELECT InventoryQC.QC_Key
                 , InventoryQC.Refno
                 , InventoryQC.Reason
                 , CONVERT(NVARCHAR(215), InventoryQC.Notes)
            FROM InventoryQC (NOLOCK)
            WHERE InventoryQC.QC_Key = LEFT(@c_sourcekey, 10)

            IF ISNULL(RTRIM(@c_arcdbname), '') <> '' AND @@ROWCOUNT = 0
            BEGIN
               SELECT @sql = N'INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks) '
                             + +N' SELECT INVENTORYQC.QC_Key, INVENTORYQC.RefNo, '
                             + N'        INVENTORYQC.Reason, CONVERT(NVARCHAR(215),INVENTORYQC.Notes) ' + N' FROM '
                             + RTRIM(@c_arcdbname) + N'.dbo.INVENTORYQC INVENTORYQC (NOLOCK) '
                             + N' WHERE INVENTORYQC.QC_Key = LEFT(@c_sourcekey,10) '

               SET @c_SQLArgument = N''
               SET @c_SQLArgument = N'@c_sourcekey nvarchar(20) '

               EXEC sp_executesql @sql, @c_SQLArgument, @c_sourcekey
            END

            SELECT TOP 1 @c_referencekey = Referencekey
                       , @c_externreferencekey = ExternReferencekey
                       , @c_externreferencetype = ExternReferenceType
                       , @c_remarks = Remarks
            FROM #TMP_REF
         END

         IF (@c_sourcetype = 'ntrKitDetailAdd' OR @c_sourcetype = 'ntrKitDetailUpdate')
         BEGIN
            SET @c_sourcetypedesc = N'Kitting'

            TRUNCATE TABLE #TMP_REF

            INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType, Remarks)
            SELECT KIT.KITKey
                 , KIT.ExternKitKey
                 , KIT.Type
                 , CONVERT(NVARCHAR(215), KIT.Remarks)
            FROM KIT (NOLOCK)
            WHERE KIT.KITKey = LEFT(@c_sourcekey, 10)

            IF ISNULL(RTRIM(@c_arcdbname), '') <> '' AND @@ROWCOUNT = 0
            BEGIN
               SELECT @sql = N'INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks) '
                             + +N' SELECT KIT.Kitkey, KIT.ExternKitKey, '
                             + N'        KIT.Type, CONVERT(NVARCHAR(215),KIT.Remarks) ' + N' FROM '
                             + RTRIM(@c_arcdbname) + N'.dbo.KIT KIT (NOLOCK) '
                             + N' WHERE KIT.KitKey = LEFT(@c_sourcekey,10) '

               SET @c_SQLArgument = N''
               SET @c_SQLArgument = N'@c_sourcekey nvarchar(20) '

               EXEC sp_executesql @sql, @c_SQLArgument, @c_sourcekey
            END

            SELECT TOP 1 @c_referencekey = Referencekey
                       , @c_externreferencekey = ExternReferencekey
                       , @c_externreferencetype = ExternReferenceType
                       , @c_remarks = Remarks
            FROM #TMP_REF
         END

         IF (LEFT(@c_sourcetype, 10) = 'CC Deposit' OR LEFT(@c_sourcetype, 13) = 'CC Withdrawal')
         BEGIN
            SET @c_sourcetypedesc = N'Count'

            TRUNCATE TABLE #TMP_REF

            INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType, Remarks)
            SELECT StockTakeSheetParameters.StockTakeKey
                 , StockTakeSheetParameters.StorerKey
                 , StockTakeSheetParameters.Facility
                 , ''
            FROM StockTakeSheetParameters (NOLOCK)
            WHERE StockTakeSheetParameters.StockTakeKey = LEFT(@c_sourcekey, 10)

            IF ISNULL(RTRIM(@c_arcdbname), '') <> '' AND @@ROWCOUNT = 0
            BEGIN
               SELECT @sql = N'INSERT INTO #TMP_REF (Referencekey, ExternReferencekey, ExternReferenceType,Remarks) '
                             + +N' SELECT STOCKTAKESHEETPARAMETERS.StockTakeKey, STOCKTAKESHEETPARAMETERS.StorerKey, '
                             + N'        STOCKTAKESHEETPARAMETERS.Facility, '''' ' + N' FROM ' + RTRIM(@c_arcdbname)
                             + N'.dbo.STOCKTAKESHEETPARAMETERS STOCKTAKESHEETPARAMETERS (NOLOCK) '
                             + N' WHERE STOCKTAKESHEETPARAMETERS.StockTakeKey = LEFT(@c_sourcekey,10) '

               SET @c_SQLArgument = N''
               SET @c_SQLArgument = N'@c_sourcekey nvarchar(20) '

               EXEC sp_executesql @sql, @c_SQLArgument, @c_sourcekey
            END

            SELECT TOP 1 @c_referencekey = Referencekey
                       , @c_externreferencekey = ExternReferencekey
                       , @c_externreferencetype = ExternReferenceType
                       , @c_remarks = Remarks
            FROM #TMP_REF
         END

         UPDATE #TMP_ITRN WITH (ROWLOCK)
         SET SourceTypeDesc = ISNULL(@c_sourcetypedesc, '')
           , ReferenceKey = ISNULL(@c_referencekey, '')
           , ExternReferenceKey = ISNULL(@c_externreferencekey, '')
           , ExternReferenceType = ISNULL(@c_externreferencetype, '')
           , Remarks = ISNULL(@c_remarks, '')
         WHERE rowid = @n_rowid

         FETCH NEXT FROM C_ItemLoop
         INTO @n_rowid
            , @c_sourcekey
            , @c_sourcetype
            , @c_Trantype2
      END
      CLOSE C_ItemLoop
      DEALLOCATE C_ItemLoop

      SET @d_Trace_EndTime = GETDATE()
      SET @c_Trace_Step2 = CONVERT(VARCHAR(22), @d_Trace_Step2, 120)
      SET @c_Trace_Step3 = CONVERT(VARCHAR(22), @d_Trace_Step3, 120)

      EXEC isp_InsertTraceInfo @c_TraceCode = 'GetInvTrace'
                             , @c_TraceName = 'isp_RPT_RP_INVENTORY_TRACE_DM'
                             , @c_Starttime = @d_Trace_StartTime
                             , @c_Endtime = @d_Trace_EndTime
                             , @c_step1 = ''
                             , @c_step2 = @c_Trace_Step2
                             , @c_step3 = @c_Trace_Step3
                             , @c_step4 = ''
                             , @c_step5 = ''
                             , @c_col1 = @c_Trace_Col1
                             , @c_col2 = @c_Trace_Col2
                             , @c_col3 = @c_Trace_Col3
                             , @c_col4 = @c_Trace_Col4
                             , @c_col5 = ''
                             , @b_Success = 1
                             , @n_Err = 0
                             , @c_ErrMsg = ''

      SELECT storerkey
           , Facility
           , effectivedate
           , SourceTypeDesc
           , trantype
           , sku
           , fromloc
           , toloc
           , fromid
           , toid
           , lot
           , qty
           , caseqty
           , ipqty
           , uom
           , Lottable01
           , Lottable02
           , Lottable03
           , Lottable04
           , Lottable05
           , Lottable06
           , Lottable07
           , Lottable08
           , Lottable09
           , Lottable10
           , Lottable11
           , Lottable12
           , Lottable13
           , Lottable14
           , Lottable15
           , ReferenceKey
           , ExternReferenceKey
           , ExternReferenceType
           , Remarks
           , addwho
           , adddate
           , editwho
           , editdate
           , itrnkey
           , descr
           , style
           , color
           , size
           , measurement
           , packkey
           , uomqty
           , ITRNstatus
      FROM #TMP_ITRN
      ORDER BY storerkey
             , Facility
             , adddate
             , sku
             , lot

      TRUNCATE TABLE #TMP_ITRN

      IF OBJECT_ID('tempdb..#TMP_ITRN') IS NOT NULL
         DROP TABLE #TMP_ITRN
   END
END

GO