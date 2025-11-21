SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_print_wave_pickslip_04                     */
/*                 modified from nsp_GetPickSlipOrders75 (ver 2018-03-08)*/
/* Creation Date: 22-Jan-2021                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: WMS-16168 - D-MOP Consolidated Pick Slip in WavePlan         */
/*          (Pickheader.Zone = 7)                                        */
/*                                                                       */
/* Called By: RCM - Wave Reports -> Generate Pick Slip                   */
/*            Datawidnow r_hk_print_wave_pickslip_04                     */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 2021-08-26   Michael  v1.1 Add Showfield Update_PD_PickslipNo         */
/* 2022-03-23   Michael  V1.2 Add NULL to Temp Table                     */
/*************************************************************************/

CREATE PROC [dbo].[isp_r_hk_print_wave_pickslip_04] (
       @as_storerkey  NVARCHAR(15) = ''
     , @as_wavekey    NVARCHAR(4000) = ''
     , @as_pickslipno NVARCHAR(4000) = ''
     , @as_loadkey    NVARCHAR(4000) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS OFF

/* CODELKUP.REPORTCFG
   [MAPFIELD]
      ShipToAddress, RefNo, Style, Color, Size, SkuGroup, PackQtyIndicator, Lottable02

   [MAPVALUE]
      T_RefNo, T_SkuGroup

   [SHOWFIELD]
      HideLocDescr, HidePackQtyIndicator
      Update_PD_PickslipNo

   [SQLJOIN]
*/
   DECLARE @c_DataWindow         NVARCHAR(40)  = 'r_hk_print_wave_pickslip_04'
         , @n_continue           INT           = 1
         , @n_StartTCnt          INT           = @@TRANCOUNT
         , @c_Pickheaderkey      NVARCHAR(10)
         , @n_Pickheaderkey      INT
         , @c_Loadkey            NVARCHAR(10)
         , @n_NoOfPS_Required    INT
         , @c_ErrMsg             NVARCHAR(255)
         , @b_Success            INT
         , @n_Err                INT
         , @b_PrintFromWaveplan  INT           = 0
         , @c_Storerkey          NVARCHAR(15)
         , @c_Storer_Logo        NVARCHAR(60)
         , @c_ExecStatements     NVARCHAR(MAX)
         , @c_ExecArguments      NVARCHAR(MAX)
         , @c_JoinClause         NVARCHAR(MAX)
         , @c_ShowFields         NVARCHAR(MAX)
         , @c_ShipToAddressExp   NVARCHAR(MAX)
         , @c_ExtOrderKeyExp     NVARCHAR(MAX)
         , @c_RefNoExp           NVARCHAR(MAX)
         , @c_StyleExp           NVARCHAR(MAX)
         , @c_ColorExp           NVARCHAR(MAX)
         , @c_SizeExp            NVARCHAR(MAX)
         , @c_SkuGroupExp        NVARCHAR(MAX)
         , @c_PackQtyIndExp      NVARCHAR(MAX)
         , @c_Lottable02Exp      NVARCHAR(MAX)

   IF ISNULL(@as_storerkey,'')<>''
      AND ( (ISNULL(@as_wavekey,'')=''  AND ISNULL(@as_pickslipno,'')=''           AND ISNULL(@as_loadkey,'')='')
         OR (ISNULL(@as_wavekey,'')='0' AND ISNULL(@as_pickslipno,'')='ZZZZZZZZZZ' AND ISNULL(@as_loadkey,'')='0') )
      AND EXISTS(SELECT TOP 1 1 FROM dbo.WAVE (NOLOCK) WHERE Wavekey = @as_storerkey)
   BEGIN
      SET @as_wavekey = @as_storerkey
      SELECT @b_PrintFromWaveplan = 1
           , @as_storerkey        = ''
           , @as_pickslipno       = ''
           , @as_loadkey          = ''
   END


   IF OBJECT_ID('tempdb..#TEMP_PICKHEADER') IS NOT NULL
      DROP TABLE #TEMP_PICKHEADER
   IF OBJECT_ID('tempdb..#TEMP_PIKDT') IS NOT NULL
      DROP TABLE #TEMP_PIKDT
   IF OBJECT_ID('tempdb..#TEMP_WAVEKEY') IS NOT NULL
      DROP TABLE #TEMP_WAVEKEY
   IF OBJECT_ID('tempdb..#TEMP_PICKSLIPNO') IS NOT NULL
      DROP TABLE #TEMP_PICKSLIPNO
   IF OBJECT_ID('tempdb..#TEMP_LOADKEY') IS NOT NULL
      DROP TABLE #TEMP_LOADKEY


   CREATE TABLE #TEMP_PICKHEADER (
        LoadKey          NVARCHAR(10)   NULL
      , Storerkey        NVARCHAR(15)   NULL
      , PickSlipNo       NVARCHAR(10)   NULL
      , PickSlipNo_New   NVARCHAR(10)   NULL
   )

   CREATE TABLE #TEMP_PIKDT (
        WaveKey          NVARCHAR(10)   NULL
      , LoadKey          NVARCHAR(10)   NULL
      , PickSlipNo       NVARCHAR(10)   NULL
      , StorerKey        NVARCHAR(15)   NULL
      , StorerCompany    NVARCHAR(45)   NULL
      , ExternOrderKey   NVARCHAR(50)   NULL
      , DeliveryDate     DATETIME       NULL
      , C_Company        NVARCHAR(45)   NULL
      , C_Address1       NVARCHAR(45)   NULL
      , C_Address2       NVARCHAR(45)   NULL
      , C_Address3       NVARCHAR(45)   NULL
      , C_Address4       NVARCHAR(45)   NULL
      , C_City           NVARCHAR(45)   NULL
      , Route            NVARCHAR(10)   NULL
      , Sku              NVARCHAR(50)   NULL
      , SkuDescr         NVARCHAR(60)   NULL
      , LogicalLocation  NVARCHAR(10)   NULL
      , Loc              NVARCHAR(10)   NULL
      , LocDescr         NVARCHAR(60)   NULL
      , PackUOM3         NVARCHAR(10)   NULL
      , Qty              INT            NULL
      , PrintedFlag      NVARCHAR(1)    NULL
      , ShipToAddress    NVARCHAR(500)  NULL
      , RefNo            NVARCHAR(500)  NULL
      , Style            NVARCHAR(500)  NULL
      , Color            NVARCHAR(500)  NULL
      , Size             NVARCHAR(500)  NULL
      , SkuGroup         NVARCHAR(500)  NULL
      , PackQtyIndicator NVARCHAR(500)  NULL
      , Lottable02       NVARCHAR(500)  NULL
      , ShowFields       NVARCHAR(4000) NULL
      , Storer_Logo      NVARCHAR(60)   NULL
   )


   SELECT DISTINCT value = LTRIM(RTRIM(value))
     INTO #TEMP_WAVEKEY
     FROM STRING_SPLIT(REPLACE(@as_wavekey   ,CHAR(13)+CHAR(10),','), ',')
    WHERE value<>''

   SELECT DISTINCT value = LTRIM(RTRIM(value))
     INTO #TEMP_PICKSLIPNO
     FROM STRING_SPLIT(REPLACE(@as_pickslipno,CHAR(13)+CHAR(10),','), ',')
    WHERE value<>''

   SELECT DISTINCT value = LTRIM(RTRIM(value))
     INTO #TEMP_LOADKEY
     FROM STRING_SPLIT(REPLACE(@as_loadkey   ,CHAR(13)+CHAR(10),','), ',')
    WHERE value<>''



   -- Get Loadkey in the Wave
   IF @b_PrintFromWaveplan = 1
   BEGIN
      INSERT INTO #TEMP_PICKHEADER (Loadkey, Storerkey, PickslipNo)
      SELECT Loadkey    = OH.Loadkey
           , Storerkey  = CASE WHEN COUNT(DISTINCT OH.Storerkey)=1 THEN MAX(OH.Storerkey) ELSE '' END
           , PickslipNo = MAX(PH.PickHeaderkey)
        FROM dbo.WAVEDETAIL WD (NOLOCK)
        JOIN dbo.ORDERS     OH (NOLOCK) ON WD.Orderkey = OH.Orderkey
        JOIN dbo.PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
        LEFT JOIN dbo.PICKHEADER PH (NOLOCK) ON OH.Loadkey  = PH.ExternOrderkey AND ISNULL(PH.Orderkey,'') = '' AND ISNULL(PH.Zone,'') = '7'
       WHERE WD.wavekey = @as_wavekey
         AND ISNULL(OH.Loadkey,'')<>''
         AND OH.Status < '5'
         AND (PD.Pickmethod = '8' OR PD.Pickmethod = '')
       GROUP BY OH.Loadkey
   END
   ELSE
   BEGIN
      INSERT INTO #TEMP_PICKHEADER (Loadkey, Storerkey, PickslipNo)
      SELECT Loadkey    = OH.Loadkey
           , Storerkey  = CASE WHEN COUNT(DISTINCT OH.Storerkey)=1 THEN MAX(OH.Storerkey) ELSE '' END
           , PickslipNo = MAX(PH.PickHeaderkey)
        FROM dbo.WAVEDETAIL WD (NOLOCK)
        JOIN dbo.ORDERS     OH (NOLOCK) ON WD.Orderkey = OH.Orderkey
        JOIN dbo.PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
        JOIN dbo.PICKHEADER PH (NOLOCK) ON OH.Loadkey  = PH.ExternOrderkey AND ISNULL(PH.Orderkey,'') = '' AND ISNULL(PH.Zone,'') = '7'
       WHERE OH.Storerkey = @as_storerkey
         AND (ISNULL(@as_wavekey,'')<>'' OR ISNULL(@as_pickslipno,'')<>'' OR ISNULL(@as_loadkey,'')<>'')
         AND (ISNULL(@as_wavekey   ,'')='' OR WD.wavekey       IN (SELECT value FROM #TEMP_WAVEKEY)   )
         AND (ISNULL(@as_pickslipno,'')='' OR PH.Pickheaderkey IN (SELECT value FROM #TEMP_PICKSLIPNO))
         AND (ISNULL(@as_loadkey   ,'')='' OR OH.Loadkey       IN (SELECT value FROM #TEMP_LOADKEY)   )
         AND ISNULL(OH.Loadkey,'')<>''
         AND OH.Status < '9'
         AND (PD.Pickmethod = '8' OR PD.Pickmethod = '')
       GROUP BY OH.Loadkey
   END

   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Conso by Loadkey, 8 - By Order
   -- Update PickType: 0=New, 1=Reprint
   IF EXISTS(SELECT TOP 1 1
             FROM #TEMP_PICKHEADER TMP_PH
             JOIN dbo.PICKHEADER PH (NOLOCK) ON TMP_PH.Loadkey = PH.ExternOrderkey AND ISNULL(PH.Orderkey,'') = '' AND ISNULL(PH.Zone,'') = '7'
             WHERE PH.PickType = '0')
   BEGIN
      BEGIN TRAN

      UPDATE PH WITH(ROWLOCK)
         SET PickType   = '1'
           , EditDate   = GETDATE()
           , EditWho    = SUSER_SNAME()
           , TrafficCop = NULL
        FROM #TEMP_PICKHEADER TMP_PH
        JOIN dbo.PICKHEADER PH ON TMP_PH.Loadkey = PH.ExternOrderkey AND ISNULL(PH.Orderkey,'') = '' AND ISNULL(PH.Zone,'') = '7'
       WHERE PH.PickType = '0'

      SELECT @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         SELECT @n_continue = 3
         IF @@TRANCOUNT >= 1
         BEGIN
            ROLLBACK TRAN
            GOTO QUIT
         END
      END
      ELSE
      BEGIN
         IF @@TRANCOUNT > 0
            COMMIT TRAN
         ELSE
         BEGIN
            SELECT @n_continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END
      END
   END

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN


   IF @b_PrintFromWaveplan = 1
   BEGIN
      -- Generate PickHeader
      SET @n_NoOfPS_Required = 0
      SELECT @n_NoOfPS_Required = COUNT(DISTINCT Loadkey)
        FROM #TEMP_PICKHEADER
       WHERE ISNULL(PickslipNo,'')=''

      IF @n_NoOfPS_Required > 0
      BEGIN
         BEGIN TRAN

         EXECUTE nspg_GetKey
                 'PICKSLIP'
               , 9
               , @c_Pickheaderkey OUTPUT
               , @b_Success       OUTPUT
               , @n_Err           OUTPUT
               , @c_ErrMsg        OUTPUT
               , 0
               , @n_NoOfPS_Required

         WHILE @@TRANCOUNT > 0
            COMMIT TRAN

         SET @n_Pickheaderkey = TRY_PARSE(ISNULL(@c_Pickheaderkey,'') AS INT) - 1

         UPDATE PH
         SET PickSlipNo_New = PSN.PickSlipNo_New
         FROM #TEMP_PICKHEADER PH
         JOIN (
            SELECT Loadkey
                 , PickSlipNo_New = 'P' + RIGHT(REPLICATE('0',9) + CONVERT(VARCHAR(10), @n_Pickheaderkey + (ROW_NUMBER() OVER(ORDER BY Loadkey)) ), 9)
              FROM #TEMP_PICKHEADER
             WHERE ISNULL(PickslipNo,'')=''
             GROUP BY Loadkey
         ) PSN ON PH.Loadkey = PSN.Loadkey


         BEGIN TRAN

         INSERT INTO PICKHEADER (PickHeaderKey, Orderkey, Externorderkey, WaveKey, PickType, Zone, TrafficCop, StorerKey, Loadkey)
         SELECT MAX(TMP_PH.PickSlipNo_New)
              , ''
              , TMP_PH.Loadkey
              , ''
              , '0'          -- PickType
              , '7'          -- Zone
              , ''
              , MAX(TMP_PH.Storerkey)
              , TMP_PH.Loadkey
           FROM #TEMP_PICKHEADER TMP_PH
          WHERE ISNULL(TMP_PH.PickslipNo,'') = ''
            AND ISNULL(TMP_PH.PickSlipNo_New,'')<>''
          GROUP BY TMP_PH.Loadkey

         SELECT @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SELECT @n_continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > 0
               COMMIT TRAN
         END


         IF EXISTS(SELECT TOP 1 1
                    FROM #TEMP_PICKHEADER PH
                    JOIN dbo.ORDERS       OH(NOLOCK) ON PH.Loadkey=OH.Loadkey AND ISNULL(OH.Loadkey,'')<>''
                    JOIN dbo.CODELKUP     RC(NOLOCK) ON RC.Listname='REPORTCFG' AND RC.Code='SHOWFIELD' AND RC.Long=@c_DataWindow AND RC.Short='Y' AND RC.Storerkey=OH.Storerkey
                   WHERE ISNULL(PH.PickslipNo,'')=''
                     AND ISNULL(PH.PickslipNo_New,'')<>''
                     AND TRIM(RC.UDF01) + LOWER(TRIM(RC.Notes)) + TRIM(RC.UDF01) LIKE '%,Update_PD_PickslipNo,%')
         BEGIN
            UPDATE PD WITH(ROWLOCK)
               SET PickslipNo = PH.PickslipNo_New
              FROM #TEMP_PICKHEADER PH
              JOIN dbo.ORDERS       OH(NOLOCK) ON PH.Loadkey=OH.Loadkey AND ISNULL(OH.Loadkey,'')<>''
              JOIN dbo.PICKDETAIL   PD         ON OH.Orderkey=PD.Orderkey
             WHERE ISNULL(PH.PickslipNo,'')=''
               AND ISNULL(PH.PickslipNo_New,'')<>''
               AND ISNULL(PD.PickslipNo,'')<>ISNULL(PH.PickslipNo_New,'')
               AND PD.Status < '9'
               AND PD.ShipFlag <> 'Y'
         END
      END
   END


   -- Storerkey Loop
   DECLARE C_CUR_STORERKEY CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT PD.Storerkey
     FROM dbo.WAVEDETAIL   WD    (NOLOCK)
     JOIN dbo.ORDERS       OH    (NOLOCK) ON WD.Orderkey = OH.Orderkey
     JOIN dbo.PICKHEADER   PH    (NOLOCK) ON OH.Loadkey  = PH.ExternOrderkey AND ISNULL(PH.Orderkey,'') = '' AND ISNULL(PH.Zone,'') = '7'
     JOIN dbo.PICKDETAIL   PD    (NOLOCK) ON OH.Orderkey = PD.Orderkey
     JOIN #TEMP_PICKHEADER TMP_PH(NOLOCK) ON OH.Loadkey  = TMP_PH.Loadkey
    WHERE ISNULL(OH.Loadkey,'')<>''
    ORDER BY 1

   OPEN C_CUR_STORERKEY

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_CUR_STORERKEY
       INTO @c_Storerkey

      IF @@FETCH_STATUS<>0
         BREAK

      SELECT @c_JoinClause         = ''
           , @c_ShowFields         = ''
           , @c_Storer_Logo        = ''
           , @c_ShipToAddressExp   = ''
           , @c_ExtOrderKeyExp     = ''
           , @c_RefNoExp           = ''
           , @c_StyleExp           = ''
           , @c_ColorExp           = ''
           , @c_SizeExp            = ''
           , @c_SkuGroupExp        = ''
           , @c_PackQtyIndExp      = ''
           , @c_Lottable02Exp      = ''

      SELECT TOP 1
             @c_JoinClause = Notes
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='SQLJOIN' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2

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
             @c_ShipToAddressExp= ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='ShipToAddress')), '' )
           , @c_ExtOrderKeyExp  = ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='ExternOrderkey')), '' )
           , @c_RefNoExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='RefNo')), '' )
           , @c_StyleExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='Style')), '' )
           , @c_ColorExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='Color')), '' )
           , @c_SizeExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='Size')), '' )
           , @c_SkuGroupExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='SkuGroup')), '' )
           , @c_PackQtyIndExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='PackQtyIndicator')), '' )
           , @c_Lottable02Exp   = ISNULL(RTRIM((select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='Lottable02')), '' )
        FROM dbo.CODELKUP (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      SET @c_ExecStatements =
        N'INSERT INTO #TEMP_PIKDT ('
        +    ' WaveKey, LoadKey, PickSlipNo, StorerKey, StorerCompany, C_Company, C_Address1, C_Address2, C_Address3, C_Address4'
        +   ', C_City, Route, DeliveryDate, Sku, SkuDescr, LogicalLocation, Loc, LocDescr, PackUOM3, Qty, PrintedFlag'
        +   ', ShipToAddress, ExternOrderKey, RefNo, Style, Color, Size, SkuGroup, PackQtyIndicator, Lottable02'
        +   ', ShowFields, Storer_Logo)'

      SET @c_ExecStatements = @c_ExecStatements
        + ' SELECT Wavekey          = ISNULL(RTRIM( WD.Wavekey), '''')'
        +       ', Loadkey          = ISNULL(RTRIM( OH.Loadkey), '''')'
        +       ', PickSlipNo       = ISNULL(RTRIM( PH.PickheaderKey), '''')'
        +       ', Storerkey        = ISNULL(RTRIM( FIRST_VALUE(PD.Storerkey ) OVER(PARTITION BY OH.Loadkey ORDER BY OH.Orderkey)), '''')'
        +       ', StorerCompany    = ISNULL(RTRIM( FIRST_VALUE(ST.Company   ) OVER(PARTITION BY OH.Loadkey ORDER BY OH.Orderkey)), '''')'
        +       ', C_Company        = ISNULL(RTRIM( FIRST_VALUE(OH.C_Company ) OVER(PARTITION BY OH.Loadkey ORDER BY OH.Orderkey)), '''')'
        +       ', C_Address1       = ISNULL(RTRIM( FIRST_VALUE(OH.C_Address1) OVER(PARTITION BY OH.Loadkey ORDER BY OH.Orderkey)), '''')'
        +       ', C_Address2       = ISNULL(RTRIM( FIRST_VALUE(OH.C_Address2) OVER(PARTITION BY OH.Loadkey ORDER BY OH.Orderkey)), '''')'
        +       ', C_Address3       = ISNULL(RTRIM( FIRST_VALUE(OH.C_Address3) OVER(PARTITION BY OH.Loadkey ORDER BY OH.Orderkey)), '''')'
        +       ', C_Address4       = ISNULL(RTRIM( FIRST_VALUE(OH.C_Address4) OVER(PARTITION BY OH.Loadkey ORDER BY OH.Orderkey)), '''')'
        +       ', C_City           = ISNULL(RTRIM( FIRST_VALUE(OH.C_City    ) OVER(PARTITION BY OH.Loadkey ORDER BY OH.Orderkey)), '''')'
        +       ', Route            = ISNULL(RTRIM( FIRST_VALUE(OH.Route     ) OVER(PARTITION BY OH.Loadkey ORDER BY OH.Orderkey)), '''')'
        +       ', DeliveryDate     = FIRST_VALUE(OH.DeliveryDate) OVER(PARTITION BY OH.Loadkey ORDER BY OH.Orderkey)'
        +       ', Sku              = ISNULL(RTRIM( PD.Sku),'''')'
        +       ', SkuDescr         = ISNULL(RTRIM( SKU.Descr),'''')'
        +       ', LogicalLocation  = ISNULL(RTRIM( LOC.LogicalLocation), '''')'
        +       ', Loc              = ISNULL(RTRIM( PD.Loc),'''')'
        +       ', LocDescr         = ISNULL(RTRIM( LOC.Descr),'''')'
        +       ', PackUOM3         = ISNULL(RTRIM( PACK.PackUOM3), '''')'
        +       ', Qty              = PD.Qty'
        +       ', PrintedFlag      = CASE WHEN PH.PickType = ''1'' THEN ''Y'' ELSE ''N'' END'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', ShipToAddress    =        RTRIM(' + CASE WHEN ISNULL(@c_ShipToAddressExp,'')<>'' THEN @c_ShipToAddressExp ELSE 'NULL'                 END + ')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', ExternOrderKey   = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ExtOrderKeyExp  ,'')<>'' THEN @c_ExtOrderKeyExp
                                                       ELSE 'CASE WHEN (SELECT COUNT(DISTINCT a.Orderkey) FROM dbo.ORDERS a(NOLOCK) WHERE a.Loadkey=OH.Loadkey AND a.Loadkey<>'''')=1 THEN OH.ExternOrderkey END' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', RefNo            = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_RefNoExp        ,'')<>'' THEN @c_RefNoExp         ELSE 'NULL'                 END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Style            = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_StyleExp        ,'')<>'' THEN @c_StyleExp         ELSE 'SKU.Style'            END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Color            = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ColorExp        ,'')<>'' THEN @c_ColorExp         ELSE 'SKU.Color'            END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Size             = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SizeExp         ,'')<>'' THEN @c_SizeExp          ELSE 'SKU.Size'             END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', SkuGroup         = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SkuGroupExp     ,'')<>'' THEN @c_SkuGroupExp      ELSE 'SKU.SkuGroup'         END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', PackQtyIndicator = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_PackQtyIndExp   ,'')<>'' THEN @c_PackQtyIndExp    ELSE 'SKU.PackQtyIndicator' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lottable02       = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lottable02Exp   ,'')<>'' THEN @c_Lottable02Exp    ELSE 'LA.Lottable02'        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', ShowFields       = ISNULL(RTRIM( @c_ShowFields), '''')'
        +       ', Storer_Logo      = ISNULL(RTRIM( @c_Storer_Logo), '''')'

      SET @c_ExecStatements = @c_ExecStatements
        +   ' FROM dbo.WAVEDETAIL   WD    (NOLOCK)'
        +   ' JOIN dbo.ORDERS       OH    (NOLOCK) ON WD.Orderkey = OH.Orderkey'
        +   ' JOIN dbo.PICKHEADER   PH    (NOLOCK) ON OH.Loadkey  = PH.ExternOrderkey AND ISNULL(PH.Orderkey,'''')='''' AND ISNULL(PH.Zone,'''')=''7'''
        +   ' JOIN dbo.PICKDETAIL   PD    (NOLOCK) ON OH.Orderkey = PD.Orderkey'
        +   ' JOIN dbo.PACK         PACK  (NOLOCK) ON PD.Packkey = PACK.Packkey'
        +   ' JOIN dbo.LOC          LOC   (NOLOCK) ON PD.Loc = LOC.Loc'
        +   ' JOIN dbo.SKU          SKU   (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku'
        +   ' JOIN dbo.LOTATTRIBUTE LA    (NOLOCK) ON PD.Lot = LA.Lot'
        +   ' JOIN dbo.STORER       ST    (NOLOCK) ON PD.Storerkey = ST.Storerkey'
        +   ' JOIN #TEMP_PICKHEADER TMP_PH(NOLOCK) ON OH.Loadkey = TMP_PH.Loadkey'
      SET @c_ExecStatements = @c_ExecStatements
        +   CASE WHEN ISNULL(@c_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(LTRIM(RTRIM(@c_JoinClause)),'') END

      SET @c_ExecStatements = @c_ExecStatements
        +   ' WHERE PD.Storerkey = @c_Storerkey'
        +     ' AND ISNULL(OH.Loadkey,'''')<>'''''


      SET @c_ExecArguments = N'@c_ShowFields  NVARCHAR(MAX)'
                           + ',@c_Storerkey   NVARCHAR(15)'
                           + ',@c_Storer_Logo NVARCHAR(60)'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_ShowFields
                       , @c_Storerkey
                       , @c_Storer_Logo
   END
   CLOSE C_CUR_STORERKEY
   DEALLOCATE C_CUR_STORERKEY


   SELECT Wavekey          = UPPER( X.Wavekey )
        , Storerkey        = UPPER( X.Storerkey )
        , StorerCompany    = MAX( X.StorerCompany )
        , PickSlipNo       = UPPER( X.PickSlipNo )
        , LoadKey          = UPPER( X.LoadKey )
        , ExternOrderKey   = MAX( X.ExternOrderKey )
        , DeliveryDate     = MAX( X.DeliveryDate )
        , C_Company        = MAX( X.C_Company )
        , C_Address1       = MAX( X.C_Address1 )
        , C_Address2       = MAX( X.C_Address2 )
        , C_Address3       = MAX( X.C_Address3 )
        , C_Address4       = MAX( X.C_Address4 )
        , C_City           = MAX( X.C_City )
        , ShipToAddress    = MAX( X.ShipToAddress )
        , Route            = MAX( X.Route )
        , SKu              = UPPER( X.Sku )
        , SkuDescr         = MAX( X.SkuDescr )
        , LogicalLocation  = UPPER( MAX( X.LogicalLocation ) )
        , Loc              = UPPER( X.Loc )
        , LocDescr         = UPPER( X.LocDescr )
        , PackUOM3         = MAX( X.PackUOM3 )
        , Qty              = SUM( X.Qty )
        , PrintedFlag      = MAX( X.PrintedFlag )
        , RefNo            = X.RefNo
        , Style            = X.Style
        , Color            = X.Color
        , Size             = X.Size
        , SkuGroup         = X.SkuGroup
        , PackQtyIndicator = X.PackQtyIndicator
        , Lottable02       = X.Lottable02
        , DWName           = @c_DataWindow
        , ShowFields       = MAX( X.ShowFields )
        , Storer_Logo      = MAX( X.Storer_Logo )
        , Lbl_RefNo        = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_RefNo') ) AS NVARCHAR(500))
        , Lbl_SkuGroup     = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_SkuGroup') ) AS NVARCHAR(500))
   FROM #TEMP_PIKDT X

   LEFT JOIN (
      SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPVALUE' AND Long=@c_DataWindow AND Short='Y'
   ) RptCfg3
   ON RptCfg3.Storerkey=X.Storerkey AND RptCfg3.SeqNo=1

   GROUP BY X.Wavekey
          , X.Storerkey
          , X.PickSlipNo
          , X.LoadKey
          , X.SKU
          , X.Loc
          , X.LocDescr
          , X.RefNo
          , X.Style
          , X.Color
          , X.Size
          , X.SkuGroup
          , X.PackQtyIndicator
          , X.Lottable02
    ORDER BY LoadKey, LogicalLocation, Loc, Style, Color, Size, Sku

QUIT:
   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN

   IF @n_continue=3
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT > @n_StartTCnt
         ROLLBACK TRAN
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
            COMMIT TRAN
      END
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_r_hk_print_wave_pickslip_04'
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
         COMMIT TRAN
      RETURN
   END
END

GO