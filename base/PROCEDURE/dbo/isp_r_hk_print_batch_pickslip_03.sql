SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_print_batch_pickslip_03                    */
/* Creation Date: 25-Nov-2020                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Batch Pickslip                                               */
/*                                                                       */
/* Called By: RCM - Print Batch Pick Slips in LoadPlan                   */
/*            Datawidnow r_hk_print_batch_pickslip_03                    */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 2021-10-08   Michael  V1.1 Fix mult-PickHeader created when using SCE */
/*                            Add Showfield: NoGenPickHeader             */
/* 2021-11-30   Michael  V1.2 Fix RptCfg.ShowFields NULL value issue     */
/* 2022-03-23   Michael  V1.3 Add NULL to Temp Table                     */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_print_batch_pickslip_03] (
       @c_Loadkey  NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

/* CODELKUP.REPORTCFG
   [MAPFIELD]
      AltSku, LineRemark1, LineRemark2, LineRemark3

   [MAPVALUE]

   [SHOWFIELD]
      LineRemark1, LineRemark2, LineRemark3
      HideAltSku, NoGenPickHeader
      
*/
   DECLARE @c_DataWindow       NVARCHAR(40)  = 'r_hk_print_batch_pickslip_03'
         , @n_continue         INT           = 1
         , @n_StartTCnt        INT           = @@TRANCOUNT
         , @c_PickHeaderkey    NVARCHAR(10)
         , @c_TmpLoadkey       NVARCHAR(10)
         , @c_errmsg           NVARCHAR(255)
         , @b_success          INT
         , @n_err              INT
         , @c_Storerkey        NVARCHAR(15)
         , @c_Storer_Logo      NVARCHAR(60)
         , @c_ExecStatements   NVARCHAR(MAX)
         , @c_ExecArguments    NVARCHAR(MAX)
         , @c_ShowFields       NVARCHAR(MAX)
         , @c_AltSkuExp        NVARCHAR(MAX)
         , @c_LineRemark1Exp   NVARCHAR(MAX)
         , @c_LineRemark2Exp   NVARCHAR(MAX)
         , @c_LineRemark3Exp   NVARCHAR(MAX)

   IF OBJECT_ID('tempdb..#TEMP_PIKDT') IS NOT NULL
      DROP TABLE #TEMP_PIKDT

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN


   -- Generate PickHeader
   DECLARE PICK_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
    SELECT DISTINCT OH.Loadkey
      FROM dbo.LOADPLANDETAIL  LPD(NOLOCK)
      JOIN dbo.ORDERS          OH (NOLOCK) ON LPD.Orderkey = OH.Orderkey
      JOIN dbo.PICKDETAIL      PD (NOLOCK) ON LPD.Orderkey = PD.Orderkey
      LEFT JOIN dbo.PICKHEADER PH (NOLOCK) ON OH.Orderkey = PH.Orderkey
      LEFT JOIN dbo.PICKHEADER PH2(NOLOCK) ON OH.Loadkey  = PH2.ExternOrderkey AND ISNULL(PH2.Orderkey,'')='' AND ISNULL(OH.Loadkey,'')<>''
      LEFT JOIN (
         SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
              , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
           FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'
      ) RptCfg
      ON RptCfg.Storerkey=OH.Storerkey AND RptCfg.SeqNo=1
     WHERE LPD.Loadkey = @c_Loadkey
       AND OH.UserDefine08 = 'N' -- only unalLocated order flag are taken into consideration - used for loadplan allocation only.
       AND PD.Status < '5'
       AND (PD.Pickmethod = '8' OR PD.Pickmethod = '')
       AND PH.PickHeaderKey IS NULL
       AND PH2.PickHeaderKey IS NULL
       AND NOT (ISNULL(RptCfg.ShowFields,'') LIKE '%,NoGenPickHeader,%')
    ORDER BY 1

   OPEN PICK_CUR

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM PICK_CUR INTO @c_TmpLoadkey

      IF @@FETCH_STATUS<>0
         BREAK

      EXECUTE nspg_GetKey
              'PICKSLIP'
            , 9
            , @c_Pickheaderkey OUTPUT
            , @b_success       OUTPUT
            , @n_err           OUTPUT
            , @c_errmsg        OUTPUT

      SELECT @c_Pickheaderkey = 'P' + @c_Pickheaderkey

      BEGIN TRAN

      INSERT INTO dbo.PICKHEADER WITH(ROWLOCK)
             (PickHeaderkey   , ExternOrderkey, PickType, Zone, TrafficCop)
      VALUES (@c_PickHeaderkey, @c_TmpLoadkey , '0'     , '9' , ''        )

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         ROLLBACK TRAN
         GOTO QUIT
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > 0
            COMMIT TRAN
      END

      -- Update pickdetail with the PickSlipNo.
      UPDATE PD WITH (ROWLocK)
         SET PickSlipNo = @c_PickHeaderkey
           , Trafficcop = NULL
           , EDITDATE   = GETDATE()
        FROM LOADPLANDETAIL LPD WITH (NOLOCK)
        JOIN ORDERS         OH  WITH (NOLOCK) ON LPD.Orderkey = OH.Orderkey
        JOIN PICKDETAIL     PD                ON LPD.Orderkey = PD.Orderkey
       WHERE LPD.Loadkey = @c_Loadkey
         AND OH.UserDefine08 = 'N'
         AND PD.Status < '5'
         AND PD.PickSlipNo IS NULL
         AND ( PD.Pickmethod = '8' OR PD.Pickmethod = '') -- includes manual picks.
   END

   CLOSE PICK_CUR
   DEALLOCATE PICK_CUR




   CREATE TABLE #TEMP_PIKDT (
        Loadkey          NVARCHAR(10)   NULL
      , Storerkey        NVARCHAR(15)   NULL
      , PickSlipNo       NVARCHAR(10)   NULL
      , Zone             NVARCHAR(1)    NULL
      , Facility         NVARCHAR(5)    NULL
      , ExternLoadkey    NVARCHAR(30)   NULL
      , DeliveryDate     DATETIME       NULL
      , Delivery_Zone    NVARCHAR(30)   NULL
      , Route            NVARCHAR(10)   NULL
      , Route_Desc       NVARCHAR(60)   NULL
      , TrfRoom          NVARCHAR(10)   NULL
      , Notes1           NVARCHAR(4000) NULL
      , Notes2           NVARCHAR(4000) NULL
      , PrintedFlag      NVARCHAR(1)    NULL
      , VehicleNo        NVARCHAR(10)   NULL
      , AlLocatedCube    FLOAT          NULL
      , AlLocatedWeight  FLOAT          NULL
      , Sku              NVARCHAR(20)   NULL
      , SkuDesc          NVARCHAR(60)   NULL
      , Putawayzone      NVARCHAR(10)   NULL
      , ZoneDesc         NVARCHAR(60)   NULL
      , LogicalLocation  NVARCHAR(18)   NULL
      , Loc              NVARCHAR(10)   NULL
      , ID               NVARCHAR(20)   NULL
      , AltSku           NVARCHAR(20)   NULL
      , Lottable02       NVARCHAR(18)   NULL
      , Lottable04       DATETIME       NULL
      , Qty              INT            NULL
      , CaseCnt          INT            NULL
      , InnerPack        INT            NULL
      , LineRemark1      NVARCHAR(500)  NULL
      , LineRemark2      NVARCHAR(500)  NULL
      , LineRemark3      NVARCHAR(500)  NULL
      , ShowFields       NVARCHAR(4000) NULL
      , Storer_Logo      NVARCHAR(60)   NULL
   )

   -- Storerkey Loop
   DECLARE C_CUR_STORERKEY CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT PD.Storerkey
     FROM dbo.LOADPLANDETAIL LPD WITH (NOLOCK)
     JOIN dbo.ORDERS         OH  WITH (NOLOCK) ON LPD.Orderkey = OH.Orderkey
     JOIN dbo.PICKHEADER     PH  WITH (NOLOCK) ON OH.Loadkey = PH.ExternOrderkey AND ISNULL(PH.Orderkey,'')='' AND ISNULL(OH.Loadkey,'')<>''
     JOIN dbo.PICKDETAIL     PD  WITH (NOLOCK) ON OH.OrderKey = PD.OrderKey
    WHERE LPD.Loadkey = @c_Loadkey
      AND OH.Status >= '1' AND OH.Status <= '9'
      AND ( PD.PickMethod = '8' OR PD.PickMethod = '' )
    ORDER BY 1

   OPEN C_CUR_STORERKEY

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_CUR_STORERKEY
       INTO @c_Storerkey

      IF @@FETCH_STATUS<>0
         BREAK

      SELECT @c_ShowFields     = ''
           , @c_Storer_Logo    = ''
           , @c_AltSkuExp      = ''
           , @c_LineRemark1Exp = ''
           , @c_LineRemark2Exp = ''
           , @c_LineRemark3Exp = ''

      SELECT TOP 1
             @c_ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
      FROM dbo.CODELKUP (NOLOCK)
      WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2

      SELECT TOP 1
             @c_Storer_Logo = RTRIM( ISNULL( RL.Notes, '') )
        FROM dbo.CODELKUP RL(NOLOCK)
       WHERE Listname='RPTLOGO' AND Code='LOGO' AND Long=@c_DataWindow
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      SELECT TOP 1
             @c_AltSkuExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='AltSku')), '' )
           , @c_LineRemark1Exp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='LineRemark1')), '' )
           , @c_LineRemark2Exp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='LineRemark2')), '' )
           , @c_LineRemark3Exp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='LineRemark3')), '' )
        FROM dbo.CODELKUP (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      SET @c_ExecStatements =
        N'INSERT INTO #TEMP_PIKDT ('
        +    ' Loadkey, Storerkey, PickSlipNo, Zone, Facility, ExternLoadkey, DeliveryDate, Delivery_zone, Route, Route_Desc,'
        +    ' TrfRoom, Notes1, Notes2, PrintedFlag, VehicleNo, AlLocatedCube, AlLocatedWeight, Sku, SkuDesc, PutawayZone,'
        +    ' ZoneDesc, LogicalLocation, Loc, ID, AltSku, Lottable02, Lottable04, Qty,'
        +    ' CaseCnt, InnerPack, LineRemark1, LineRemark2, LineRemark3, ShowFields, Storer_Logo)'

      SET @c_ExecStatements = @c_ExecStatements
        + ' SELECT Loadkey          = RTRIM(LPD.Loadkey)'
        +       ', Storerkey        = RTRIM(OH.Storerkey)'
        +       ', PickSlipNo       = RTRIM(PH.Pickheaderkey)'
        +       ', Zone             = ''9'''
        +       ', Facility         = RTRIM(ISNULL(LP.Facility,''''))'
        +       ', ExternLoadkey    = RTRIM(ISNULL(LP.ExternLoadkey,''''))'
        +       ', DeliveryDate     = LP.LPUSERDEFDATE01'
        +       ', Delivery_zone    = RTRIM(CASE WHEN ISNULL(LP.Route, '''')=ISNULL(LP.Delivery_Zone,'''')'
        +                                 ' THEN ISNULL(LP.Route, '''')'
        +                                 ' ELSE LTRIM(RTRIM(ISNULL(LP.Route, '''')) +'
        +                                      ' IIF(ISNULL(LP.Route,'''')<>'''' AND ISNULL(LP.Delivery_Zone,'''')<>'''', '', '', '''') +'
        +                                      ' LTRIM(ISNULL(LP.Delivery_Zone,'''')))'
        +                           ' END)'
        +       ', Route            = RTRIM(ISNULL(LP.Route, ''''))'
        +       ', Route_Desc       = RTRIM(ISNULL(RM.Descr, ''''))'
        +       ', TrfRoom          = RTRIM(ISNULL(LP.TrfRoom, ''''))'
        +       ', Notes1           = RTRIM(ISNULL(LP.Load_Userdef1, ''''))'
        +       ', Notes2           = RTRIM(ISNULL(LP.Load_Userdef2, ''''))'
        +       ', PrintedFlag      = CASE WHEN PH.PickType = ''1'' THEN ''Y'' ELSE ''N'' END'
        +       ', VehicleNo        = RTRIM(ISNULL(VH.VehicleNumber, ''''))'
        +       ', AlLocatedCube    = ISNULL(LP.AlLocatedCube, 0.0)'
        +       ', AlLocatedWeight  = ISNULL(LP.AlLocatedWeight, 0.0)'
        +       ', Sku              = RTRIM(PD.Sku)'
        +       ', SkuDesc          = RTRIM(ISNULL(SKU.Descr,''''))'
        +       ', PutawayZone      = RTRIM(ISNULL(LOC.PutawayZone,''''))'
        +       ', ZoneDesc         = RTRIM(PA.Descr)'
        +       ', LogicalLocation  = RTRIM(Loc.LogicalLocation)'
        +       ', Loc              = RTRIM(PD.Loc)'
        +       ', ID               = RTRIM(PD.ID)'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', AltSku           = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_AltSkuExp,'')<>'' THEN @c_AltSkuExp ELSE 'SKU.AltSku' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lottable02       = RTRIM(ISNULL(LA.Lottable02, ''''))'
        +       ', Lottable04       = LA.Lottable04'
        +       ', Qty              = PD.Qty'
        +       ', CaseCnt          = PACK.CaseCnt'
        +       ', InnerPack        = PACK.InnerPack'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', LineRemark1      = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRemark1Exp,'')<>'' THEN @c_LineRemark1Exp ELSE 'NULL' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', LineRemark2      = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRemark2Exp,'')<>'' THEN @c_LineRemark2Exp ELSE 'NULL' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', LineRemark3      = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRemark3Exp,'')<>'' THEN @c_LineRemark3Exp ELSE 'NULL' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', ShowFields       = @c_ShowFields'
        +       ', Storer_Logo      = RTRIM( ISNULL( @c_Storer_Logo, '''') )'

      SET @c_ExecStatements = @c_ExecStatements
        +  ' FROM dbo.LOADPLANDETAIL LPD  WITH (NOLOCK)'
        +  ' JOIN dbo.LOADPLAN       LP   WITH (NOLOCK) ON LPD.Loadkey = LP.Loadkey'
        +  ' JOIN dbo.ORDERS         OH   WITH (NOLOCK) ON LPD.Orderkey = OH.Orderkey'
        +  ' JOIN ('
        +     ' SELECT *, SeqNo = ROW_NUMBER() OVER(PARTITION BY ExternOrderkey ORDER BY CASE WHEN Zone=''9'' THEN 1 ELSE 2 END, PickHeaderKey)'
        +     ' FROM dbo.PICKHEADER (NOLOCK) WHERE ExternOrderkey<>'''' AND ISNULL(Orderkey,'''')='''''
        +   ') PH ON OH.Loadkey = PH.ExternOrderkey AND PH.SeqNo=1'

        +  ' JOIN dbo.PICKDETAIL     PD   WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey'
        +  ' JOIN dbo.SKU            SKU  WITH (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku'
        +  ' JOIN dbo.PACK           PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey'
        +  ' JOIN dbo.LOTATTRIBUTE   LA   WITH (NOLOCK) ON PD.Lot = LA.Lot'
        +  ' JOIN dbo.LOC            LOC  WITH (NOLOCK) ON PD.Loc = LOC.Loc'
        +  ' LEFT JOIN dbo.PUTAWAYZONE    PA  WITH (NOLOCK) ON LOC.PutawayZone = PA.PutawayZone'
        +  ' LEFT JOIN dbo.IDS_LP_VEHICLE VH  WITH (NOLOCK) ON LPD.Loadkey = VH.Loadkey AND VH.Linenumber = ''00001'''
        +  ' LEFT JOIN dbo.ROUTEMASTER    RM  WITH (NOLOCK) ON LP.Route = RM.Route'

      SET @c_ExecStatements = @c_ExecStatements
        + ' WHERE OH.Storerkey = @c_Storerkey'
        +   ' AND LPD.Loadkey  = @c_Loadkey'
        +   ' AND OH.Status >= ''1'' AND OH.Status <= ''9'''
        +   ' AND ( PD.PickMethod = ''8'' OR PD.PickMethod = '''' )'

      SET @c_ExecArguments = N'@c_DataWindow  NVARCHAR(40)'
                           + ',@c_ShowFields  NVARCHAR(MAX)'
                           + ',@c_Loadkey     NVARCHAR(10)'
                           + ',@c_Storerkey   NVARCHAR(15)'
                           + ',@c_Storer_Logo NVARCHAR(60)'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_DataWindow
                       , @c_ShowFields
                       , @c_Loadkey
                       , @c_Storerkey
                       , @c_Storer_Logo
   END

   CLOSE C_CUR_STORERKEY
   DEALLocATE C_CUR_STORERKEY


   -- Uses PickType as a Printed Flag
   IF EXISTS(SELECT TOP 1 1
             FROM #TEMP_PIKDT PIKDT
             JOIN dbo.PICKHEADER PH(NOLOCK) ON PIKDT.PickslipNo = PH.PickHeaderkey
             WHERE PH.PickType = '0')
   BEGIN
      BEGIN TRAN

      UPDATE PH WITH(ROWLOCK)
         SET PickType = '1'
           , EditDate = GETDATE()
           , EditWho  = SUSER_SNAME()
           , TrafficCop = NULL
        FROM dbo.PICKHEADER PH
       WHERE PH.PickHeaderkey IN (SELECT DISTINCT PickslipNo FROM #TEMP_PIKDT WHERE PickslipNo<>'')
         AND PH.PickType = '0'

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         IF @@TRANCOUNT >= 1
            ROLLBACK TRAN
      END
      ELSE
      BEGIN
         IF @@TRANCOUNT > 0
            COMMIT TRAN
         ELSE
         BEGIN
            SELECT @n_continue = 3
            ROLLBACK TRAN
         END
      END
   END


   SELECT Loadkey         = UPPER( X.Loadkey )
        , Storerkey       = UPPER( X.Storerkey )
        , PickSlipNo      = UPPER( X.PickSlipNo )
        , Zone            = MAX( X.Zone )
        , Facility        = MAX( X.Facility )
        , ExternLoadkey   = MAX( X.ExternLoadkey )
        , DeliveryDate    = MAX( X.DeliveryDate )
        , Delivery_Zone   = MAX( X.Delivery_Zone )
        , Route           = UPPER( MAX( X.Route ) )
        , Route_Desc      = MAX( X.Route_Desc )
        , TrfRoom         = MAX( X.TrfRoom )
        , Notes1          = MAX( X.Notes1 )
        , Notes2          = MAX( X.Notes2 )
        , PrintedFlag     = MAX( X.PrintedFlag )
        , VehicleNo       = MAX( X.VehicleNo )
        , AlLocatedCube   = MAX( X.AlLocatedCube )
        , AlLocatedWeight = MAX( X.AlLocatedWeight )
        , Sku             = X.Sku
        , SkuDesc         = MAX( X.SkuDesc )
        , Putawayzone     = UPPER( MAX( X.Putawayzone ) )
        , ZoneDesc        = MAX( X.ZoneDesc )
        , LogicalLocation = UPPER( MAX( X.LogicalLocation ) )
        , Loc             = UPPER( X.Loc )
        , ID              = UPPER( X.ID )
        , AltSku          = X.AltSku
        , Lottable02      = X.Lottable02
        , Lottable04      = X.Lottable04
        , Qty             = SUM( X.Qty )
        , CaseCnt         = MAX( X.CaseCnt )
        , InnerPack       = MAX( X.InnerPack )
        , Cartons         = CASE WHEN ISNULL(MAX(X.CaseCnt  ),0)=0 THEN 0 ELSE FLOOR(SUM(X.Qty) / MAX(X.CaseCnt)) END
        , Inners          = CASE WHEN ISNULL(MAX(X.InnerPack),0)=0 THEN 0 ELSE FLOOR( IIF(ISNULL(MAX(X.CaseCnt),0)=0, SUM(X.Qty), SUM(X.Qty) % MAX(X.CaseCnt)) / MAX(X.InnerPack)) END
        , Pieces          = CASE WHEN ISNULL(MAX(X.InnerPack),0)=0 THEN IIF(ISNULL(MAX(X.CaseCnt),0)=0, SUM(X.Qty), SUM(X.Qty) % MAX(X.CaseCnt))
                                                                   ELSE IIF(ISNULL(MAX(X.CaseCnt),0)=0, SUM(X.Qty), SUM(X.Qty) % MAX(X.CaseCnt)) % MAX(X.InnerPack) END
        , LineRemark1     = X.LineRemark1
        , LineRemark2     = X.LineRemark2
        , LineRemark3     = X.LineRemark3
        , ShowFields      = MAX( X.ShowFields )
        , Storer_Logo     = MAX( X.Storer_Logo )
   FROM #TEMP_PIKDT X
   GROUP BY X.Loadkey
          , X.Storerkey
          , X.PickSlipNo
          , X.Sku
          , X.AltSku
          , X.Putawayzone
          , X.LogicalLocation
          , X.Loc
          , X.ID
          , X.Lottable02
          , X.Lottable04
          , X.LineRemark1
          , X.LineRemark2
          , X.LineRemark3
   ORDER BY PickSlipNo, Sku, LogicalLocation, Loc, ID

   DROP TABLE #TEMP_PIKDT

QUIT:
   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN

   IF @n_continue=3
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT > @n_StartTCnt
         ROLLBACK TRAN
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
            COMMIT TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_r_hk_print_batch_pickslip_03'
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
         COMMIT TRAN
      RETURN
   END
END

GO