SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_replenishment_report_06                    */
/* Creation Date: 13-Sep-2018                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Replenishment Report                                         */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_replenishment_report_06     */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 14/12/2018   ML       1.1  1. Fix parameter @as_zones len issue       */
/*                            2. Add new parameter @as_sku               */
/* 03/01/2019   ML       1.2  Handle QtyReplen & PendingMovein           */
/* 07/03/2019   ML       1.3  Change to use SEQKey table for SeqTbl      */
/* 23/03/2022   ML       1.4  Add NULL to Temp Table                     */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_replenishment_report_06] (
  @as_storerkey   NVARCHAR(15)
, @as_facility    NVARCHAR(10)
, @as_zones       NVARCHAR(4000)
, @as_sku         NVARCHAR(4000) = ''
, @as_printlabel  NVARCHAR(10) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_DataWidnow        NVARCHAR(40)
         , @c_StorerKey         NVARCHAR(15)
         , @c_Sku               NVARCHAR(20)
         , @c_ToLOC             NVARCHAR(10)
         , @c_EachUOM           NVARCHAR(10)
         , @c_PackKey           NVARCHAR(10)
         , @c_ReplenPriority    NVARCHAR(5)
         , @n_ReplenSeverity    INT
         , @c_Barcode           NVARCHAR(30)
         , @c_Lot               NVARCHAR(10)
         , @c_FromLOC           NVARCHAR(10)
         , @c_Id                NVARCHAR(30)
         , @c_ReplenGroup       NVARCHAR(10)
         , @c_ReplenGroupDyn    NVARCHAR(10)
         , @c_ReplenishmentKey  NVARCHAR(10)
         , @n_CtnAvail          INT
         , @n_Qty               INT
         , @n_CaseCnt           INT
         , @c_CaseUOM           NVARCHAR(10)
         , @n_ReplenCtn         INT
         , @n_ReplenQty         INT
         , @n_Temp              INT
         , @n_RowID             INT
         , @b_success           INT
         , @n_err               INT
         , @c_errmsg            NVARCHAR(255)
         , @c_ExecStatements    NVARCHAR(MAX)
         , @c_ExecArguments     NVARCHAR(MAX)
         , @c_ShowFields        NVARCHAR(4000)
         , @c_JoinClausePF      NVARCHAR(4000)
         , @c_WhereClausePF     NVARCHAR(4000)
         , @c_JoinClauseRV      NVARCHAR(4000)
         , @c_WhereClauseRV     NVARCHAR(4000)
         , @c_OrderByClauseRV   NVARCHAR(4000)
         , @c_ReplenSeverityExp NVARCHAR(4000)
         , @c_BarcodeExp        NVARCHAR(4000)
         , @c_DynCaseCntExp     NVARCHAR(4000)
         , @c_CaseUOMExp        NVARCHAR(4000)

   IF OBJECT_ID('tempdb..#TEMP_SKUXLOC') IS NOT NULL
      DROP TABLE #TEMP_SKUXLOC
   IF OBJECT_ID('tempdb..#TEMP_LOTXLOCXID') IS NOT NULL
      DROP TABLE #TEMP_LOTXLOCXID
   IF OBJECT_ID('tempdb..#TEMP_REPLENISHMENT') IS NOT NULL
      DROP TABLE #TEMP_REPLENISHMENT

   SELECT @c_DataWidnow  = 'r_hk_replenishment_report_06'
        , @c_ReplenGroup = 'IDS'
        , @c_ReplenGroupDyn = 'DYNAMIC'

   CREATE TABLE #TEMP_SKUXLOC (
        RowID      INT IDENTITY(1,1) NOT NULL Primary Key
      , StorerKey      NVARCHAR(15)  NOT NULL
      , SKU            NVARCHAR(20)  NOT NULL
      , LOC            NVARCHAR(10)  NOT NULL
      , EachUOM        NVARCHAR(10)  NULL
      , PackKey        NVARCHAR(10)  NULL
      , ReplenPriority NVARCHAR(5 )  NULL
      , ReplenSeverity INT           NULL
      , Barcode        NVARCHAR(30)  NULL
   )

   CREATE TABLE #TEMP_LOTXLOCXID (
        RowID      INT IDENTITY(1,1) NOT NULL Primary Key
      , Lot            NVARCHAR(10)  NOT NULL
      , LOC            NVARCHAR(10)  NOT NULL
      , Id             NVARCHAR(30)  NOT NULL
      , Storerkey      NVARCHAR(15)  NULL
      , Sku            NVARChAR(20)  NULL
      , CtnAvail       INT           NULL
      , CaseCnt        INT           NULL
      , CaseUOM        NVARCHAR(10)  NULL
   )

   CREATE TABLE #TEMP_REPLENISHMENT (
        RowID      INT IDENTITY(1,1) NOT NULL Primary Key
      , ReplenishmentKey NVARCHAR(10) NULL
      , StorerKey        NVARCHAR(20) NULL
      , SKU              NVARCHAR(20) NULL
      , FromLOC          NVARCHAR(10) NULL
      , ToLOC            NVARCHAR(10) NULL
      , LOT              NVARCHAR(10) NULL
      , ID               NVARCHAR(18) NULL
      , QTY              INT          NULL
      , ReplenPriority   NVARCHAR(5)  NULL
      , EachUOM          NVARCHAR(10) NULL
      , PACKKEY          NVARCHAR(10) NULL
      , ReplenSeverity   INT          NULL
      , ReplenCasecnt    INT          NULL
      , CaseUOM          NVARCHAR(10) NULL
      , Barcode          NVARCHAR(30) NULL
   )

   SELECT @c_ShowFields        = ''
        , @c_JoinClausePF      = ''
        , @c_WhereClausePF     = ''
        , @c_JoinClauseRV      = ''
        , @c_WhereClauseRV     = ''
        , @c_OrderByClauseRV   = ''
        , @c_ReplenSeverityExp = ''
        , @c_BarcodeExp        = ''
        , @c_DynCaseCntExp     = ''
        , @c_CaseUOMExp        = ''


   ----------
   -- Show Fields
   SELECT TOP 1
          @c_ShowFields = ',' + LTRIM(RTRIM(Notes)) + ','
     FROM dbo.CodeLkup (NOLOCK)
    WHERE Listname='REPORTCFG' AND Code='SHOWFIELD'  AND Long=@c_DataWidnow AND Short='Y'
      AND Storerkey = @as_storerkey
    ORDER BY Code2

   ----------
   -- Pick Face
   SELECT TOP 1
          @c_JoinClausePF = Notes
     FROM dbo.CodeLkup (NOLOCK)
    WHERE Listname='REPORTCFG' AND Code='SQLJOIN'  AND Long=@c_DataWidnow AND Short='Y' AND UDF02='PICKFACE'
      AND Storerkey = @as_storerkey
    ORDER BY Code2

    SELECT TOP 1
          @c_WhereClausePF = Notes
     FROM dbo.CodeLkup (NOLOCK)
    WHERE Listname='REPORTCFG' AND Code='SQLWHERE' AND Long=@c_DataWidnow AND Short='Y' AND UDF02='PICKFACE'
      AND Storerkey = @as_storerkey
    ORDER BY Code2

   ----------
   -- Reserve
   SELECT TOP 1
          @c_JoinClauseRV = Notes
     FROM dbo.CodeLkup (NOLOCK)
    WHERE Listname='REPORTCFG' AND Code='SQLJOIN'  AND Long=@c_DataWidnow AND Short='Y' AND UDF02='RESERVE'
      AND Storerkey = @as_storerkey
    ORDER BY Code2

    SELECT TOP 1
          @c_WhereClauseRV = Notes
     FROM dbo.CodeLkup (NOLOCK)
    WHERE Listname='REPORTCFG' AND Code='SQLWHERE' AND Long=@c_DataWidnow AND Short='Y' AND UDF02='RESERVE'
      AND Storerkey = @as_storerkey
    ORDER BY Code2

    SELECT TOP 1
          @c_OrderByClauseRV = Notes
     FROM dbo.CodeLkup (NOLOCK)
    WHERE Listname='REPORTCFG' AND Code='SQLORDERBY' AND Long=@c_DataWidnow AND Short='Y' AND UDF02='RESERVE'
      AND Storerkey = @as_storerkey
    ORDER BY Code2

   ----------
   SELECT TOP 1
          @c_ReplenSeverityExp  = ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='ReplenSeverity')), '' )
        , @c_BarcodeExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='Barcode')), '' )
        , @c_DynCaseCntExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='DynCaseCnt')), '' )
        , @c_CaseUOMExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='CaseUOM')), '' )
     FROM dbo.CodeLkup (NOLOCK)
    WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWidnow AND Short='Y'
      AND Storerkey = @as_storerkey
    ORDER BY Code2


   ----------
   SET @c_ExecStatements =
         N'INSERT #TEMP_SKUXLOC (StorerKey, SKU, LOC, EachUOM, PackKey, ReplenPriority, ReplenSeverity, Barcode)'
       + ' SELECT SKUxLOC.Storerkey'
              +', SKUxLOC.Sku'
              +', SKUxLOC.Loc'
              +', PACK.PackUOM3'
              +', SKU.PackKey'
              +', SKUxLOC.ReplenishmentPriority'
   SET @c_ExecStatements = @c_ExecStatements
              +', ISNULL(' + CASE WHEN ISNULL(@c_ReplenSeverityExp,'')<>'' THEN @c_ReplenSeverityExp
                  ELSE 'SKUxLOC.QtyLocationLimit - SKUxLOC.Qty + SKUxLOC.QtyPicked '
                     + '- ISNULL((SELECT SUM(IIF(ISNULL(a.PendingMoveIN,0)<0,0,a.PendingMoveIN)) FROM dbo.LOTxLOCxID a(NOLOCK)'
                     +   ' WHERE a.Storerkey=SKUxLOC.Storerkey AND a.Sku=SKUxLOC.Sku AND a.Loc=SKUxLOC.Loc),0)'
                  END + ',0)'
   SET @c_ExecStatements = @c_ExecStatements
              +', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_BarcodeExp,'')<>'' THEN @c_BarcodeExp ELSE ''''''  END + '),'''')'

   SET @c_ExecStatements = @c_ExecStatements
       +' FROM dbo.SKUxLOC SKUxLOC (NOLOCK)'
       +' JOIN dbo.LOC     LOC     (NOLOCK) ON SKUxLOC.LOC = LOC.LOC'
       +' JOIN dbo.SKU     SKU     (NOLOCK) ON SKUxLOC.Storerkey = SKU.Storerkey AND SKUxLOC.Sku = SKU.Sku'
       +' JOIN dbo.PACK    PACK    (NOLOCK) ON SKU.PackKey = PACK.PACKKey'
   SET @c_ExecStatements = @c_ExecStatements
       + CASE WHEN ISNULL(@c_JoinClausePF,'')<>'' THEN ' ' + ISNULL(LTRIM(RTRIM(@c_JoinClausePF)),'') ELSE '' END

   SET @c_ExecStatements = @c_ExecStatements
       +' WHERE SKUxLOC.LocationType IN (''PICK'', ''CASE'')'
       + ' AND LOC.LocationFlag NOT IN (''DAMAGE'', ''HOLD'')'
       + ' AND LOC.FACILITY = @as_facility'
       + ' AND (@as_zones = ''ALL'' OR LOC.PutawayZone IN'
       +     ' (SELECT DISTINCT LTRIM(RTRIM(ColValue)) FROM dbo.fnc_DelimSplit('','',REPLACE(@as_zones,CHAR(13)+CHAR(10),'','')) WHERE ColValue<>''''))'
       + ' AND SKUxLOC.Storerkey = @as_storerkey'

   IF ISNULL(@as_sku,'')<>''
      SET @c_ExecStatements = @c_ExecStatements
          + ' AND SKUxLOC.Sku IN (SELECT DISTINCT LTRIM(RTRIM(ColValue)) FROM dbo.fnc_DelimSplit('','',REPLACE(@as_sku,CHAR(13)+CHAR(10),'','')) WHERE ColValue<>'''')'

   SET @c_ExecStatements = @c_ExecStatements
       + ' AND (' + CASE WHEN ISNULL(@c_WhereClausePF,'')<>'' THEN ISNULL(LTRIM(RTRIM(@c_WhereClausePF)),'') ELSE 'SKUxLOC.Qty - SKUxLOC.QtyPicked <= SKUxLOC.QtyLocationMinimum' END + ')'


   SET @c_ExecArguments = N'@as_storerkey NVARCHAR(15)'
                        + ',@as_facility  NVARCHAR(10)'
                        + ',@as_zones     NVARCHAR(4000)'
                        + ',@as_sku       NVARCHAR(4000)'

   EXEC sp_ExecuteSql @c_ExecStatements
                    , @c_ExecArguments
                    , @as_storerkey
                    , @as_facility
                    , @as_zones
                    , @as_sku


   SET @c_ExecStatements =
         N'INSERT INTO #TEMP_LOTXLOCXID (Lot, LOC, Id, Storerkey, Sku, CtnAvail, CaseCnt, CaseUOM)'
       + ' SELECT X.Lot'
       +       ', X.Loc'
       +       ', X.Id'
       +       ', X.Storerkey'
       +       ', X.Sku'
       +       ', FLOOR( CAST(X.QtyAvail AS FLOAT) / X.CaseCnt )'
       +       ', X.CaseCnt'
       +       ', X.CaseUOM'
       + ' FROM ('
   SET @c_ExecStatements = @c_ExecStatements
       +    ' SELECT Lot       = LOTxLOCxID.Lot'
       +          ', Loc       = LOTxLOCxID.Loc'
       +          ', Id        = LOTxLOCxID.Id'
       +          ', Storerkey = LOTxLOCxID.Storerkey'
       +          ', Sku       = LOTxLOCxID.Sku'
       +          ', QtyAvail  = LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - (CASE WHEN LOTxLOCxID.QtyReplen < 0 THEN 0 ELSE LOTxLOCxID.QtyReplen END)'
   SET @c_ExecStatements = @c_ExecStatements
       +          ', CaseCnt   = ' + CASE WHEN ISNULL(@c_DynCaseCntExp,'')<>'' THEN @c_DynCaseCntExp ELSE 'IIF(PACK.CaseCnt>0, PACK.CaseCnt, IIF(PACK.InnerPack>0, PACK.InnerPack, 1))'  END
   SET @c_ExecStatements = @c_ExecStatements
       +          ', CaseUOM   = ' + CASE WHEN ISNULL(@c_CaseUOMExp,   '')<>'' THEN @c_CaseUOMExp    ELSE 'IIF(PACK.CaseCnt>0, PACK.PackUOM1, IIF(PACK.InnerPack>0, PACK.PackUOM2, ''CT''))'  END
   SET @c_ExecStatements = @c_ExecStatements
       +          ', RowID     = ROW_NUMBER() OVER(ORDER BY '
                               + CASE WHEN ISNULL(@c_OrderByClauseRV,'')<>'' THEN ISNULL(LTRIM(RTRIM(@c_OrderByClauseRV)),'')
                                      ELSE 'CASE WHEN SKU.Lottable04Label<>'''' THEN LOTATTRIBUTE.Lottable04 END, CASE WHEN SKU.Lottable02Label<>'''' THEN LOTATTRIBUTE.Lottable02 ELSE '''' END, LOTATTRIBUTE.Lottable05, LOC.LogicalLocation, LOTxLOCxID.LOC'
                                 END + ')'

   SET @c_ExecStatements = @c_ExecStatements
       +      ' FROM dbo.LOTxLOCxID   LOTxLOCxID  (NOLOCK)'
       +      ' JOIN dbo.SKUxLOC      SKUxLOC     (NOLOCK) ON LOTxLOCxID.Storerkey=SKUxLOC.Storerkey AND LOTxLOCxID.Sku=SKUxLOC.Sku AND LOTxLOCxID.Loc=SKUxLOC.Loc'
       +      ' JOIN dbo.LOC          LOC         (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc'
       +      ' JOIN dbo.LOTATTRIBUTE LOTATTRIBUTE(NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot'
       +      ' JOIN dbo.SKU          SKU         (NOLOCK) ON LOTxLOCxID.Storerkey = SKU.Storerkey AND LOTxLOCxID.Sku = SKU.Sku'
       +      ' JOIN dbo.PACK         PACK        (NOLOCK) ON SKU.PackKey = PACK.PACKKey'
   SET @c_ExecStatements = @c_ExecStatements
       +    CASE WHEN ISNULL(@c_JoinClauseRV,'')<>'' THEN ' ' + ISNULL(LTRIM(RTRIM(@c_JoinClauseRV)),'') ELSE '' END

   SET @c_ExecStatements = @c_ExecStatements
       +    ' WHERE SKUxLOC.LocationType NOT IN (''PICK'', ''CASE'')'
       +    ' AND LOC.FACILITY = @as_facility'
       +    ' AND (@as_zones = ''ALL'' OR LOC.PutawayZone IN'
       +        ' (SELECT DISTINCT LTRIM(RTRIM(ColValue)) FROM dbo.fnc_DelimSplit('','',REPLACE(@as_zones,CHAR(13)+CHAR(10),'','')) WHERE ColValue<>''''))'
       +    ' AND LOTxLOCxID.Storerkey = @as_storerkey'
       +    ' AND EXISTS(SELECT TOP 1 1 FROM #TEMP_SKUXLOC WHERE Storerkey=LOTxLOCxID.Storerkey AND Sku=LOTxLOCxID.Sku)'
       +    ' AND LOTxLOCxID.Qty > 0'
   SET @c_ExecStatements = @c_ExecStatements
       +    CASE WHEN ISNULL(@c_WhereClauseRV,'')<>'' THEN ' AND (' + ISNULL(LTRIM(RTRIM(@c_WhereClauseRV)),'') + ')' ELSE '' END

   SET @c_ExecStatements = @c_ExecStatements
       + ' ) X'
       + ' WHERE X.CaseCnt >= 1'
       +   ' AND X.QtyAvail >= X.CaseCnt'
       + ' ORDER BY X.Storerkey, X.Sku, X.RowID'

   SET @c_ExecArguments = N'@as_storerkey NVARCHAR(15)'
                        + ',@as_facility  NVARCHAR(10)'
                        + ',@as_zones     NVARCHAR(4000)'

   EXEC sp_ExecuteSql @c_ExecStatements
                    , @c_ExecArguments
                    , @as_storerkey
                    , @as_facility
                    , @as_zones


   DECLARE C_CUR_SKUXLOC CURSOR FAST_FORWARD READ_ONLY FOR
    SELECT StorerKey, SKU, LOC, EachUOM, PackKey, ReplenPriority, ReplenSeverity, Barcode
      FROM #TEMP_SKUXLOC
     ORDER BY ReplenPriority, LOC

   OPEN C_CUR_SKUXLOC

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_CUR_SKUXLOC
       INTO @c_StorerKey, @c_Sku, @c_ToLOC, @c_EachUOM, @c_PackKey, @c_ReplenPriority, @n_ReplenSeverity, @c_Barcode

      IF @@FETCH_STATUS<>0
         BREAK

      DECLARE C_CUR_LOTXLOCXID CURSOR FAST_FORWARD READ_ONLY FOR
       SELECT LLI.Lot, LLI.LOC, LLI.Id, LLI.CtnAvail, LLI.CaseCnt, LLI.CaseUOM
         FROM #TEMP_LOTXLOCXID LLI
        WHERE LLI.Storerkey = @c_StorerKey AND LLI.Sku = @c_Sku
        ORDER BY LLI.RowID

      OPEN C_CUR_LOTXLOCXID

      WHILE @n_ReplenSeverity > 0
      BEGIN
         FETCH NEXT FROM C_CUR_LOTXLOCXID
          INTO @c_Lot, @c_FromLOC, @c_Id, @n_CtnAvail, @n_CaseCnt, @c_CaseUOM

         IF @@FETCH_STATUS<>0
            BREAK

         SET @n_Temp = FLOOR( CAST(@n_ReplenSeverity AS FLOAT) / @n_CaseCnt)
         IF @n_Temp >= 1
         BEGIN
            SET @n_ReplenCtn = IIF( @n_Temp < @n_CtnAvail, @n_Temp, @n_CtnAvail )
            IF @n_ReplenCtn > 0
            BEGIN
               SET @n_ReplenQty = @n_ReplenCtn * @n_CaseCnt
               SET @n_CtnAvail -= @n_ReplenCtn
               SET @n_ReplenSeverity -= @n_ReplenQty

               -- insert replenishment record
               INSERT INTO #TEMP_REPLENISHMENT (
                      StorerKey, SKU, FromLOC, ToLOC, LOT, ID, QTY, EachUOM, CaseUOM, PackKey, ReplenPriority,
                      ReplenSeverity, ReplenCasecnt, Barcode)
               VALUES(@c_StorerKey, @c_Sku, @c_FromLOC, @c_ToLOC, @c_Lot, @c_Id, @n_ReplenQty, @c_EachUOM, @c_CaseUOM, @c_PackKey, @c_ReplenPriority,
                      @n_ReplenSeverity+@n_ReplenQty, @n_CaseCnt, @c_Barcode)

               UPDATE #TEMP_SKUXLOC
                  SET ReplenSeverity = ReplenSeverity - @n_ReplenQty
                WHERE Storerkey = @c_StorerKey AND Sku = @c_Sku AND Loc = @c_ToLOC

               UPDATE #TEMP_LOTXLOCXID
                  SET CtnAvail = CtnAvail - @n_ReplenCtn
                WHERE Lot = @c_Lot AND Loc = @c_FromLOC AND Id = @c_Id
            END
         END
      END
      CLOSE C_CUR_LOTXLOCXID
      DEALLOCATE C_CUR_LOTXLOCXID
   END

   CLOSE C_CUR_SKUXLOC
   DEALLOCATE C_CUR_SKUXLOC


   IF EXISTS(SELECT TOP 1 1 FROM #TEMP_REPLENISHMENT)
      AND @c_ShowFields LIKE '%,GenReplenishment,%'
      AND ISNULL(@as_printlabel,'')<>'Y'
   BEGIN
      -- Clear outstanding Replenishment
      UPDATE a SET ReplenishmentKey = RP.ReplenishmentKey
        FROM #TEMP_REPLENISHMENT a
        JOIN dbo.Replenishment RP(NOLOCK) ON a.Storerkey=RP.Storerkey AND a.Sku=RP.Sku AND a.FromLOC=RP.FromLOC
                                         AND a.ToLOC=RP.ToLOC AND a.Lot=RP.Lot AND a.ID=RP.ID AND a.Qty=RP.Qty
       WHERE ISNULL(RP.ReplenishmentGroup,'') <> @c_ReplenGroupDyn
         AND RP.Confirmed='N'

      DELETE RP WITH(ROWLOCK)
        FROM dbo.Replenishment RP
        JOIN dbo.LOC          LOC(NOLOCK) ON RP.ToLoc = LOC.Loc
       WHERE ISNULL(RP.ReplenishmentGroup,'') <> @c_ReplenGroupDyn
         AND RP.Confirmed = 'N'
         AND RP.Storerkey = @as_storerkey
         AND LOC.FACILITY = @as_facility
         AND (@as_zones = 'ALL' OR LOC.PutawayZone IN
             (SELECT DISTINCT LTRIM(RTRIM(ColValue)) FROM dbo.fnc_DelimSplit(',',REPLACE(@as_zones,CHAR(13)+CHAR(10),',')) WHERE ColValue<>''))
         AND RP.ReplenishmentKey NOT IN (SELECT ReplenishmentKey FROM #TEMP_REPLENISHMENT WHERE ReplenishmentKey<>'')


      -- Build Replenishment
      DECLARE C_CUR_REPLENISHMENT CURSOR FAST_FORWARD READ_ONLY FOR
       SELECT RowID, StorerKey, SKU, FromLOC, ToLOC, LOT, ID, QTY, ReplenPriority,
              EachUOM, PACKKEY, ReplenSeverity, ReplenCasecnt
         FROM #TEMP_REPLENISHMENT
        WHERE ISNULL(ReplenishmentKey,'')=''
        ORDER BY RowID

      OPEN C_CUR_REPLENISHMENT

      WHILE 1=1
      BEGIN
         FETCH NEXT FROM C_CUR_REPLENISHMENT
          INTO @n_RowID, @c_StorerKey, @c_Sku, @c_FromLOC, @c_ToLOC, @c_Lot, @c_Id, @n_QTY, @c_ReplenPriority,
               @c_EachUOM, @c_PackKey, @n_ReplenSeverity, @n_CaseCnt

         IF @@FETCH_STATUS<>0
            BREAK

         EXECUTE nspg_GetKey
            'REPLENISHKEY',
            10,
            @c_ReplenishmentKey OUTPUT,
            @b_success OUTPUT,
            @n_err OUTPUT,
            @c_errmsg OUTPUT

         IF @b_success = 1
         BEGIN
            UPDATE #TEMP_REPLENISHMENT
               SET ReplenishmentKey = @c_ReplenishmentKey
             WHERE RowID = @n_RowID

            INSERT INTO REPLENISHMENT (
                 ReplenishmentGroup, ReplenishmentKey, StorerKey, Sku, FromLoc, ToLoc, Lot, Id,
                 Qty, UOM, PackKey, Confirmed)
            VALUES(
                 @c_ReplenGroup, @c_ReplenishmentKey, @c_StorerKey, @c_Sku, @c_FromLOC, @c_ToLOC, @c_Lot, @c_Id,
                 @n_Qty, @c_EachUOM, @c_PackKey, 'N')
         END
      END
      CLOSE C_CUR_REPLENISHMENT
      DEALLOCATE C_CUR_REPLENISHMENT
   END


   IF ISNULL(@as_printlabel,'') = 'Y'
   BEGIN
      SELECT RowID            = RP.RowID
           , ReplenishmentKey = RTRIM( RP.ReplenishmentKey )
           , StorerKey        = RTRIM( RP.StorerKey )
           , SKU              = RTRIM( RP.SKU )
           , FromLOC          = RTRIM( RP.FromLOC )
           , ToLOC            = RTRIM( RP.ToLOC )
           , LOT              = RTRIM( RP.LOT )
           , ID               = RTRIM( RP.ID )
           , QTY              = RP.QTY
           , ReplenPriority   = RTRIM( RP.ReplenPriority )
           , CaseQty          = IIF(RP.ReplenCasecnt>0, RP.QTY / RP.ReplenCasecnt, 0)
           , CaseUOM          = RTRIM( RP.CaseUOM )
           , EachQty          = IIF(RP.ReplenCasecnt>0, RP.QTY % RP.ReplenCasecnt, RP.QTY)
           , EachUOM          = RTRIM( RP.EachUOM )
           , PACKKEY          = RTRIM( RP.PACKKEY )
           , ReplenSeverity   = RP.ReplenSeverity
           , ReplenCasecnt    = RP.ReplenCasecnt
           , Barcode          = RTRIM( RP.Barcode )
           , Descr            = RTRIM( SKU.Descr )
           , Company          = RTRIM( STR.Company )
           , Facility         = RTRIM( FROMLOC.Facility )
           , FromPutawayZone  = RTRIM( FROMLOC.PutawayZone )
           , FromPA_Descr     = RTRIM( FROMPA.Descr )
           , Lottable02       = RTRIM( LA.Lottable02 )
           , Lottable04       = LA.Lottable04
           , dwname           = @c_DataWidnow
           , CtnNo            = SeqTbl.Rowref
           , TotalCtn         = IIF(RP.ReplenCasecnt>0, CONVERT(INT,CEILING(CONVERT(FLOAT, RP.QTY) / RP.ReplenCasecnt)), 0)
           , FromLogicalLoc   = RTRIM ( FROMLOC.LogicalLocation )
           , ShowFields       = LOWER(@c_ShowFields)
        FROM #TEMP_REPLENISHMENT RP
        JOIN dbo.STORER         STR(NOLOCK) ON RP.Storerkey=STR.Storerkey
        JOIN dbo.SKU            SKU(NOLOCK) ON RP.Storerkey=SKU.Storerkey AND RP.Sku=SKU.Sku
        JOIN dbo.LOTATTRIBUTE    LA(NOLOCK) ON RP.Lot=LA.Lot
        JOIN dbo.LOC        FROMLOC(NOLOCK) ON RP.FromLoc=FROMLOC.Loc
        JOIN dbo.PUTAWAYZONE FROMPA(NOLOCK) ON FROMLOC.PutawayZone=FROMPA.PutawayZone
        JOIN dbo.SEQKey      SeqTbl(NOLOCK) ON SeqTbl.Rowref <= IIF(@c_ShowFields NOT LIKE '%,GenLabelPerCarton,%', 1,
                                               IIF(RP.ReplenCasecnt>0, CONVERT(INT,CEILING(CONVERT(FLOAT, RP.QTY) / RP.ReplenCasecnt)), 0) )
       WHERE IIF(RP.ReplenCasecnt>0, CONVERT(INT,CEILING(CONVERT(FLOAT, RP.QTY) / RP.ReplenCasecnt)), 0) > 0
       ORDER BY RowID, CtnNo
   END
   ELSE
   BEGIN
      SELECT RowID            = RP.RowID
           , ReplenishmentKey = RTRIM( RP.ReplenishmentKey )
           , StorerKey        = RTRIM( RP.StorerKey )
           , SKU              = RTRIM( RP.SKU )
           , FromLOC          = RTRIM( RP.FromLOC )
           , ToLOC            = RTRIM( RP.ToLOC )
           , LOT              = RTRIM( RP.LOT )
           , ID               = RTRIM( RP.ID )
           , QTY              = RP.QTY
           , ReplenPriority   = RTRIM( RP.ReplenPriority )
           , CaseQty          = IIF(RP.ReplenCasecnt>0, RP.QTY / RP.ReplenCasecnt, 0)
           , CaseUOM          = RTRIM( RP.CaseUOM )
           , EachQty          = IIF(RP.ReplenCasecnt>0, RP.QTY % RP.ReplenCasecnt, RP.QTY)
           , EachUOM          = RTRIM( RP.EachUOM )
           , PACKKEY          = RTRIM( RP.PACKKEY )
           , ReplenSeverity   = RP.ReplenSeverity
           , ReplenCasecnt    = RP.ReplenCasecnt
           , Barcode          = RTRIM( RP.Barcode )
           , Descr            = RTRIM( SKU.Descr )
           , Company          = RTRIM( STR.Company )
           , Facility         = RTRIM( FROMLOC.Facility )
           , FromPutawayZone  = RTRIM( FROMLOC.PutawayZone )
           , FromPA_Descr     = RTRIM( FROMPA.Descr )
           , Lottable02       = RTRIM( LA.Lottable02 )
           , Lottable04       = LA.Lottable04
           , dwname           = @c_DataWidnow
           , CtnNo            = 1
           , TotalCtn         = 1
           , FromLogicalLoc   = RTRIM ( FROMLOC.LogicalLocation )
           , ShowFields       = LOWER(@c_ShowFields)
       FROM #TEMP_REPLENISHMENT RP
       JOIN dbo.STORER         STR(NOLOCK) ON RP.Storerkey=STR.Storerkey
       JOIN dbo.SKU            SKU(NOLOCK) ON RP.Storerkey=SKU.Storerkey AND RP.Sku=SKU.Sku
       JOIN dbo.LOTATTRIBUTE    LA(NOLOCK) ON RP.Lot=LA.Lot
       JOIN dbo.LOC        FROMLOC(NOLOCK) ON RP.FromLoc=FROMLOC.Loc
       JOIN dbo.PUTAWAYZONE FROMPA(NOLOCK) ON FROMLOC.PutawayZone=FROMPA.PutawayZone
      ORDER BY RowID
   END
END

GO