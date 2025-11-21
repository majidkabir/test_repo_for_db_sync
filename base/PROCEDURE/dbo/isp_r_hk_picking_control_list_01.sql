SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_picking_control_list_01                    */
/* Creation Date: 23-Nov-2017                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Wave Pickslip                                                */
/*                                                                       */
/* Called By: RCM - Generate Pickslip in Waveplan                        */
/*            Datawidnow r_hk_picking_control_list_01                    */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 05/01/2018   ML       1.1  Update TrackingNo                          */
/* 13/03/2018   ML       1.2  Fix TrackingNo not update issue            */
/* 08/12/2021   ML       1.3  WMS-18543 Add MAPFIELD: DocNumber          */
/*                            MAPVALUE: T_DocNumber                      */
/* 23/03/2022   ML       1.4  Add NULL to Temp Table                     */
/* 08/02/2023   ML       1.5  WMS-18543 Add parm @as_putawayzone         */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_picking_control_list_01] (
       @as_storerkey      NVARCHAR(18)
     , @as_wavekey        NVARCHAR(18)
     , @as_putawayzone    NVARCHAR(MAX) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

/* CODELKUP.REPORTCFG
   [MAPFIELD]
      DocNumber, ReferenceNo, ItemGroup, DeliveryDateWithTime, EstimateCartonCBM
      Update_Orders_TrackingNo, Update_CartonShipmentDetail_TrackingNumber
   [MAPVALUE]
      T_DocNumber, T_ReferenceNo, StoredProc
   [SHOWFIELD]
   [SQLJOIN]
*/

   IF OBJECT_ID('tempdb..#TEMP_PUTAWAYZONE') IS NOT NULL
      DROP TABLE #TEMP_PUTAWAYZONE
   IF OBJECT_ID('tempdb..#TEMP_FINALORDERKEY') IS NOT NULL
      DROP TABLE #TEMP_FINALORDERKEY
   IF OBJECT_ID('tempdb..#TEMP_ORDET') IS NOT NULL
      DROP TABLE #TEMP_ORDET

   SELECT DISTINCT PutawayZone = TRIM(value)
   INTO #TEMP_PUTAWAYZONE
   FROM STRING_SPLIT(@as_putawayzone,',')
   WHERE value<>''

   DECLARE @c_DataWidnow         NVARCHAR(40)
         , @n_StartTCnt          INT
         , @b_FromRCMRpt         INT
         , @c_DocNumberExp       NVARCHAR(MAX)
         , @c_ReferenceNoExp     NVARCHAR(MAX)
         , @c_ItemGroupExp       NVARCHAR(MAX)
         , @c_Storerkey          NVARCHAR(15)
         , @c_ExecStatements     NVARCHAR(MAX)
         , @c_ExecArguments      NVARCHAR(MAX)
         , @c_JoinClause         NVARCHAR(MAX)
         , @c_StoredProc         NVARCHAR(MAX)
         , @c_Upd_Ord_TrackingNo NVARCHAR(MAX)
         , @c_Upd_CtnShpDt_TrkNo NVARCHAR(MAX)

   SELECT @c_DataWidnow  = 'r_hk_picking_control_list_01'
        , @n_StartTCnt   = @@TRANCOUNT
        , @b_FromRCMRpt  = 0

   -- Call SP to create PickHeader if called from RCM Report
   IF @as_wavekey='0' AND LEN(@as_storerkey)=10 AND @as_storerkey LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
   BEGIN
      SET @b_FromRCMRpt  = 1
      SET @as_wavekey    = @as_storerkey
      SET @as_storerkey  = CHAR(9)
      SET @as_putawayzone = ''

      DECLARE C_STORERKEY CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Storerkey
        FROM dbo.ORDERS (NOLOCK)
       WHERE Userdefine09<>''
         AND UserDefine09 = @as_wavekey
         AND Storerkey<>''
       ORDER BY 1

      OPEN C_STORERKEY

      WHILE 1=1
      BEGIN
         FETCH NEXT FROM C_STORERKEY
          INTO @c_Storerkey

         IF @@FETCH_STATUS<>0
            BREAK

         -- Call StoredProc
         SET @c_StoredProc = ''
         SELECT TOP 1
                @c_StoredProc = ISNULL(RTRIM((select top 1 b.ColValue
                                from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                where a.SeqNo=b.SeqNo and a.ColValue='StoredProc')), '' )
           FROM dbo.CodeLkup (NOLOCK)
          WHERE Listname='REPORTCFG' AND Code='MAPVALUE' AND Long=@c_DataWidnow AND Short='Y'
            AND Storerkey = @c_Storerkey
          ORDER BY Code2

         IF ISNULL(@c_StoredProc,'')<>''
         BEGIN
            BEGIN TRY
               EXEC @c_StoredProc @as_wavekey
               WITH RESULT SETS NONE
            END TRY
            BEGIN CATCH
            END CATCH
         END
      END

      CLOSE C_STORERKEY
      DEALLOCATE C_STORERKEY
   END


   CREATE TABLE #TEMP_ORDET (
        OrderKey         NVARCHAR(10)  NULL
      , Storerkey        NVARCHAR(15)  NULL
      , Wavekey          NVARCHAR(10)  NULL
      , Loadkey          NVARCHAR(10)  NULL
      , PickslipNo       NVARCHAR(18)  NULL
      , DocNumber        NVARCHAR(500) NULL
      , ReferenceNo      NVARCHAR(500) NULL
      , ItemGroup        NVARCHAR(500) NULL
      , OrderQty         INT           NULL
      , AllocQty         INT           NULL
      , StdCube          FLOAT         NULL
      , Putawayzone      NVARCHAR(10)  NULL
      , ConsolPick       NVARCHAR(1)   NULL
      , DocKey           NVARCHAR(10)  NULL
      , FirstOrderkey    NVARCHAR(10)  NULL
      , SeqNo            INT           NULL
   )

   -- Final Orderkey
   SELECT Orderkey       = OH.Orderkey
        , Storerkey      = MAX( OH.Storerkey )
        , PickslipNo     = MAX( PH.PickheaderKey )
        , Loadkey        = MAX( OH.Loadkey )
        , ConsolPick     = 'N'
        , DocKey         = MAX( OH.Orderkey )
     INTO #TEMP_FINALORDERKEY
     FROM dbo.ORDERS     OH (NOLOCK)
     JOIN dbo.PICKHEADER PH(NOLOCK) ON OH.OrderKey = PH.OrderKey AND PH.OrderKey<>''
    WHERE OH.UserDefine09<>''
      AND (@as_storerkey = CHAR(9) OR OH.Storerkey = @as_storerkey)
      AND OH.UserDefine09 = @as_wavekey
    GROUP BY OH.Orderkey

   INSERT INTO #TEMP_FINALORDERKEY
   SELECT Orderkey       = OH.Orderkey
        , Storerkey      = MAX( OH.Storerkey )
        , PickslipNo     = MAX( PH.PickheaderKey )
        , Loadkey        = MAX( OH.Loadkey )
        , ConsolPick     = MAX( CASE WHEN ISNULL(OH.Userdefine09,'')<>'' THEN 'Y' ELSE 'N' END )
        , DocKey         = MAX( CASE WHEN ISNULL(OH.Userdefine09,'')<>'' THEN OH.Loadkey ELSE OH.Orderkey END )
     FROM dbo.ORDERS     OH (NOLOCK)
     JOIN dbo.PICKHEADER PH (NOLOCK) ON OH.Loadkey = PH.ExternOrderkey AND ISNULL(OH.Loadkey,'')<>'' AND ISNULL(PH.Orderkey,'')=''
    LEFT JOIN #TEMP_FINALORDERKEY FOK ON OH.Orderkey = FOK.Orderkey
    WHERE OH.UserDefine09<>''
      AND (@as_storerkey = CHAR(9) OR OH.Storerkey = @as_storerkey)
      AND OH.UserDefine09 = @as_wavekey
      AND FOK.Orderkey IS NULL
    GROUP BY OH.Orderkey


   DECLARE C_STORERKEY CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Storerkey FROM #TEMP_FINALORDERKEY ORDER BY 1

   OPEN C_STORERKEY

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_STORERKEY
       INTO @c_Storerkey

      IF @@FETCH_STATUS<>0
         BREAK

      SELECT @c_DocNumberExp       = ''
           , @c_ReferenceNoExp     = ''
           , @c_ItemGroupExp       = ''
           , @c_Upd_Ord_TrackingNo = ''
           , @c_Upd_CtnShpDt_TrkNo = ''
           , @c_JoinClause         = ''

      SELECT TOP 1
             @c_JoinClause  = Notes
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='SQLJOIN' AND Long=@c_DataWidnow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      SELECT TOP 1
             @c_DocNumberExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='DocNumber')), '' )
           , @c_ReferenceNoExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ReferenceNo')), '' )
           , @c_ItemGroupExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ItemGroup')), '' )
           , @c_Upd_Ord_TrackingNo = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Update_Orders_TrackingNo')), '' )
           , @c_Upd_CtnShpDt_TrkNo = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Update_CartonShipmentDetail_TrackingNumber')), '' )
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWidnow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      -- Update ORDERS.TrackingNo
      IF ISNULL(@c_Upd_Ord_TrackingNo,'')<>''
      BEGIN
         SET @c_ExecStatements = N'UPDATE dbo.ORDERS'
                               + ' SET TrackingNo = ' + ISNULL(@c_Upd_Ord_TrackingNo,'')
                               + ' FROM #TEMP_FINALORDERKEY FOK'
                               + ' JOIN dbo.ORDERS        OH (NOLOCK) ON FOK.Orderkey=OH.Orderkey'
                               + ' LEFT JOIN dbo.LOADPLAN LP (NOLOCK) ON OH.Loadkey=LP.Loadkey'
                               + ' WHERE FOK.Storerkey=@c_Storerkey'
                               +   ' AND OH.Status<''9'''
                               +   ' AND ISNULL(OH.TrackingNo,'''')<>' + ISNULL(@c_Upd_Ord_TrackingNo,'')

         SET @c_ExecArguments = N'@c_Storerkey NVARCHAR(15)'

         EXEC sp_ExecuteSql @c_ExecStatements
                          , @c_ExecArguments
                          , @c_Storerkey
      END

      -- Update CartonShipmentDetail.TrackingNumber
      IF ISNULL(@c_Upd_CtnShpDt_TrkNo,'')<>''
      BEGIN
         SET @c_ExecStatements = N'UPDATE dbo.CartonShipmentDetail'
                               + ' SET TrackingNumber = ' + ISNULL(@c_Upd_CtnShpDt_TrkNo,'')
                               + ' FROM #TEMP_FINALORDERKEY FOK'
                               + ' JOIN dbo.ORDERS                OH (NOLOCK) ON FOK.Orderkey=OH.Orderkey'
                               + ' JOIN dbo.CartonShipmentDetail CSD (NOLOCK) ON FOK.Orderkey=CSD.Orderkey'
                               + ' WHERE FOK.Storerkey=@c_Storerkey'
                               +   ' AND OH.Status<''9'''
                               +   ' AND ISNULL(CSD.TrackingNumber,'''')<>' + ISNULL(@c_Upd_CtnShpDt_TrkNo,'')

                               + ' INSERT INTO dbo.CartonShipmentDetail (Storerkey, Orderkey, TrackingNumber)'
                               + ' SELECT DISTINCT FOK.Storerkey, OH.Orderkey, ' + ISNULL(@c_Upd_CtnShpDt_TrkNo,'')
                               + ' FROM #TEMP_FINALORDERKEY FOK'
                               + ' JOIN dbo.ORDERS OH (NOLOCK) ON FOK.Orderkey=OH.Orderkey'
                               + ' LEFT JOIN dbo.CartonShipmentDetail CSD (NOLOCK) ON FOK.Orderkey=CSD.Orderkey'
                               + ' WHERE FOK.Storerkey=@c_Storerkey'
                               + ' AND OH.Status<''9'''
                               + ' AND CSD.Orderkey IS NULL'

         SET @c_ExecArguments = N'@c_Storerkey NVARCHAR(15)'

         EXEC sp_ExecuteSql @c_ExecStatements
                          , @c_ExecArguments
                          , @c_Storerkey
      END


      ----------
      SET @c_ExecStatements = N'INSERT INTO #TEMP_ORDET'
          +' (OrderKey, Storerkey, Wavekey, Loadkey, PickslipNo'
          +', DocNumber, ReferenceNo, ItemGroup, OrderQty, AllocQty, StdCube'
          +', Putawayzone, ConsolPick, DocKey, FirstOrderkey, SeqNo)'
          +' SELECT OH.OrderKey'
               + ', OH.Storerkey'
               + ', OH.Userdefine09'
               + ', OH.Loadkey'
               + ', FOK.PickslipNo'
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DocNumberExp      ,'')<>'' THEN @c_DocNumberExp       ELSE 'FOK.DocKey' END + '),'''')'
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ReferenceNoExp    ,'')<>'' THEN @c_ReferenceNoExp     ELSE '''''' END + '),'''')'
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ItemGroupExp      ,'')<>'' THEN @c_ItemGroupExp       ELSE '''''' END + '),'''')'
               + ', OD.OriginalQty'
               + ', PD.Qty'
               + ', SKU.STDCUBE'
               + ', LOC.PutawayZone'
               + ', FOK.ConsolPick'
               + ', FOK.DocKey'
               + ', FIRST_VALUE(FOK.Orderkey) OVER(PARTITION BY FOK.DocKey ORDER BY FOK.Orderkey)'
               + ', ROW_NUMBER() OVER(PARTITION BY OH.Orderkey, OD.OrderLineNumber ORDER BY ISNULL(PD.PickdetailKey,''''))'
          +' FROM #TEMP_FINALORDERKEY FOK'
          +' JOIN dbo.ORDERS      OH (NOLOCK) ON FOK.Orderkey=OH.Orderkey'
          +' JOIN dbo.ORDERDETAIL OD (NOLOCK) ON OH.Orderkey=OD.Orderkey'
          +' JOIN dbo.SKU        SKU (NOLOCK) ON OD.StorerKey=SKU.StorerKey AND OD.Sku=SKU.Sku'
          +' LEFT JOIN dbo.PICKDETAIL PD (NOLOCK) ON OD.Orderkey=PD.Orderkey AND OD.OrderLineNumber=PD.OrderLineNumber'
          +' LEFT JOIN dbo.LOC       LOC (NOLOCK) ON PD.Loc=LOC.Loc'
          + CASE WHEN ISNULL(@c_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(LTRIM(RTRIM(@c_JoinClause)),'') END
          +' WHERE FOK.Storerkey=@c_Storerkey'

      IF ISNULL(@as_putawayzone,'')<>''
         SET @c_ExecStatements = @c_ExecStatements
          +' AND EXISTS(SELECT TOP 1 1 FROM #TEMP_PUTAWAYZONE WHERE PutawayZone=LOC.PutawayZone)'

      SET @c_ExecArguments = N'@c_Storerkey NVARCHAR(15)'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_Storerkey
   END

   CLOSE C_STORERKEY
   DEALLOCATE C_STORERKEY


   UPDATE #TEMP_ORDET
      SET OrderQty = 0
    WHERE SeqNo<>1

   ----------
   SELECT Wavekey        = RTRIM( ORDET.Wavekey )
        , ConsolPick     = MAX ( ORDET.ConsolPick )
        , DocKey         = MAX ( RTRIM( ORDET.DocKey ) )
        , ExternOrderKey = MAX ( RTRIM( CASE WHEN ORDET.ConsolPick='Y' THEN '' ELSE OH.ExternOrderKey END ) )
        , PickslipNo     = RTRIM( ORDET.PickslipNo )
        , ConsigneeKey   = MAX ( RTRIM( OH.ConsigneeKey ) )
        , C_Company      = MAX ( RTRIM( OH.C_Company ) )
        , C_Address1     = MAX ( RTRIM( OH.C_Address1 ) )
        , C_Address2     = MAX ( RTRIM( OH.C_Address2 ) )
        , C_Address3     = MAX ( RTRIM( OH.C_Address3 ) )
        , C_Address4     = MAX ( RTRIM( OH.C_Address4 ) )
        , Route          = MAX ( RTRIM( UPPER( CASE WHEN LEFT(OH.Route,2) IN ('MC', 'LT') THEN OH.Route ELSE LEFT(OH.Route,2) END ) ) )
        , ReferenceNo    = CAST( STUFF(
                         ( SELECT DISTINCT ', ', RTRIM( ISNULL( a.ReferenceNo, '' ) )
                           FROM #TEMP_ORDET a
                           WHERE a.PickslipNo=ORDET.PickslipNo AND a.ReferenceNo<>''
                           ORDER BY 2
                           FOR XML PATH('') ), 1, 2, '') AS NVARCHAR(500) )
        , OrderQty       = SUM ( ORDET.OrderQty )
        , DeliveryDate   = CASE WHEN (select top 1 b.ColValue
                              from dbo.fnc_DelimSplit(MAX(RptCfg.Delim),MAX(RptCfg.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg.Delim),MAX(RptCfg.Notes2)) b
                             where a.SeqNo=b.SeqNo and a.ColValue='DeliveryDateWithTime') = 'Y'
                           THEN CONVERT(DATETIME, CONVERT(VARCHAR(16), MAX( OH.DeliveryDate), 120))
                           ELSE CONVERT(DATETIME, CONVERT(VARCHAR(10), MAX( OH.DeliveryDate), 120))
                           END
        , ItemGroup      = CAST( STUFF(
                         ( SELECT DISTINCT ', ', RTRIM( ISNULL( a.ItemGroup, '' ) )
                           FROM #TEMP_ORDET a
                           WHERE a.PickslipNo=ORDET.PickslipNo AND a.ItemGroup<>''
                           ORDER BY 2
                           FOR XML PATH('') ), 1, 2, '') AS NVARCHAR(500) )
        , CBM            = SUM ( ORDET.StdCube * ORDET.OrderQty )
        , EstimateCtnCBM = CAST( (select top 1 b.ColValue
                               from dbo.fnc_DelimSplit(MAX(RptCfg.Delim),MAX(RptCfg.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg.Delim),MAX(RptCfg.Notes2)) b
                               where a.SeqNo=b.SeqNo and a.ColValue='EstimateCartonCBM') AS NVARCHAR(30) )
        , Putawayzones   = CAST( ( SELECT TOP 3 CONVERT(NCHAR(10),a.PutawayZone), CONVERT(NCHAR(10),ISNULL(SUM(a.AllocQty),0))
                            FROM #TEMP_ORDET a(NOLOCK)
                            WHERE a.PickslipNo=ORDET.PickslipNo AND a.PutawayZone<>'' AND a.AllocQty<>0
                            GROUP BY a.Putawayzone
                            ORDER BY 1
                            FOR XML PATH('') ) AS NVARCHAR(500) )
        , Company        = MAX ( RTRIM( STORER.Company ) )
        , datawindow     = @c_DataWidnow
        , Lbl_ReferenceNo= CAST( RTRIM( (select top 1 b.ColValue
                               from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                               where a.SeqNo=b.SeqNo and a.ColValue='T_ReferenceNo') ) AS NVARCHAR(500))
        , DocNumber      = MAX ( ISNULL( RTRIM ( ORDET.DocNumber ), '') )
        , Lbl_DocNumber  = CAST( RTRIM( (select top 1 b.ColValue
                               from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                               where a.SeqNo=b.SeqNo and a.ColValue='T_DocNumber') ) AS NVARCHAR(500))

   FROM #TEMP_ORDET ORDET
   JOIN dbo.ORDERS OH (NOLOCK) ON ORDET.FirstOrderkey = OH.Orderkey
   JOIN dbo.STORER STORER (NOLOCK) ON ORDET.StorerKey = STORER.StorerKey

   LEFT JOIN (
      SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
        FROM CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWidnow AND Short='Y'
   ) RptCfg
   ON RptCfg.Storerkey=OH.Storerkey AND RptCfg.SeqNo=1

   LEFT JOIN (
      SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
        FROM CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPVALUE' AND Long=@c_DataWidnow AND Short='Y'
   ) RptCfg3
   ON RptCfg3.Storerkey=OH.Storerkey AND RptCfg3.SeqNo=1

   GROUP BY ORDET.Wavekey
          , ORDET.PickslipNo

   ORDER BY DeliveryDate, Wavekey, Route, ConsigneeKey, C_Company, C_Address1, ExternOrderKey


   WHILE @@TRANCOUNT > @n_StartTCnt
   BEGIN
      COMMIT TRAN
   END
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO