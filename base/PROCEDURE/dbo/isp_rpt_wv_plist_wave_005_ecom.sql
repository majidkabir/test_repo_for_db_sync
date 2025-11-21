SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/      
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_005_ECOM                        */      
/* Creation Date: 30-May-2022                                              */      
/* Copyright: LFL                                                          */      
/* Written by: WLChooi                                                     */      
/*                                                                         */      
/* Purpose: WMS-19758 - [TW] JET Pick Slip CR                              */      
/*                                                                         */      
/* Called By: RPT_WV_PLIST_WAVE_005_ECOM                                   */      
/*                                                                         */      
/* GitLab Version: 1.0                                                     */      
/*                                                                         */      
/* Version: 1.0                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date         Author  Ver   Purposes                                     */    
/* 30-May-2022  WLChooi  1.0   DevOps Combine Script                       */  
/***************************************************************************/  
CREATE PROC [dbo].[isp_RPT_WV_PLIST_WAVE_005_ECOM]  
      @c_Wavekey           NVARCHAR(10)
    , @c_PreGenRptData     NVARCHAR(10)
                
AS  
BEGIN   
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE
           @n_StartTCnt       INT
         , @n_Continue        INT
         , @b_Success         INT
         , @n_Err             INT
         , @c_Errmsg          NVARCHAR(255)

         , @n_NoOfReqPSlip    INT
         , @c_Orderkey        NVARCHAR(10)
         , @c_PickSlipNo      NVARCHAR(10)
         , @c_PickHeaderKey   NVARCHAR(10)
         , @c_Storerkey       NVARCHAR(15)

         , @c_AutoScanIn      NVARCHAR(10)
         , @c_Facility        NVARCHAR(5)
         , @c_Logo            NVARCHAR(50)
         , @n_MaxLine         INT
         , @n_CntRec          INT
         , @c_MaxPSlipno      NVARCHAR(10)
         , @n_LastPage        INT
         , @n_ReqLine         INT
         , @c_JCLONG          NVARCHAR(255)
         , @c_LoadKey         NVARCHAR(10)
         , @c_Type            NVARCHAR(1) = '1'                      
         , @c_DataWindow      NVARCHAR(60) = 'RPT_WV_PLIST_WAVE_005_ECOM'  
         , @c_RetVal          NVARCHAR(255)
	
   --SELECT @c_Storerkey = Storerkey
   --FROM ORDERS (NOLOCK)
   --WHERE UserDefine09 = @c_Wavekey
--
   --EXEC [dbo].[isp_GetCompanyInfo]  
   --    @c_Storerkey  = @c_Storerkey  
   -- ,  @c_Type       = @c_Type  
   -- ,  @c_DataWindow = @c_DataWindow  
   -- ,  @c_RetVal     = @c_RetVal           OUTPUT

   SET @n_StartTCnt= @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_Err      = 0
   SET @c_Errmsg   = ''
   SET @c_Logo     = ''
   SET @n_MaxLine  = 9
   SET @n_CntRec   = 1
   SET @n_LastPage = 0
   SET @n_ReqLine  = 1

   IF ISNULL(@c_PreGenRptData,'') IN ('0','')
      SET @c_PreGenRptData = ''

   CREATE TABLE #TMP_PCK
      ( Loadkey         NVARCHAR(10)   NOT NULL
      , Orderkey        NVARCHAR(10)   NOT NULL
      , PickSlipNo      NVARCHAR(10)   NOT NULL
      , Storerkey       NVARCHAR(15)   NOT NULL
      , logo            NVARCHAR(255)  NULL   
      , Wavekey         NVARCHAR(10)   NOT NULL
      , Wavedetailkey   NVARCHAR(10)   NOT NULL
      )

   CREATE TABLE #TMP_PCK66
      ( PickSlipNo      NVARCHAR(10)   NOT NULL
      , Contact1        NVARCHAR(45)   NULL
      , ODUDF03         NVARCHAR(30)   NULL
      , Loadkey         NVARCHAR(10)   NOT NULL
      , Orderkey        NVARCHAR(10)   NOT NULL
      , OrdDate         DATETIME
      , EditDate        DATETIME
      , ExternOrderkey  NVARCHAR(50)   NULL 
      , Notes           NVARCHAR(255)  NULL
      , Loc             NVARCHAR(20)   NULL
      , Storerkey       NVARCHAR(15)   NOT NULL
      , SKU             NVARCHAR(20)   NULL
      , PFUDF01         NVARCHAR(255)  NULL
      , EMUDF01         NVARCHAR(255)  NULL
      , Qty             INT
      , JCLONG          NVARCHAR(255)  NULL
      , Pageno          INT
      , RptNotes        NVARCHAR(255)                 
      )

   SET @c_Facility = ''
   SELECT @c_Facility = Facility
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = WD.OrderKey
   WHERE WD.WaveKey = @c_Wavekey

   INSERT INTO #TMP_PCK
      ( Loadkey
      , Orderkey
      , PickSlipNo
      , Storerkey
      , logo
      , Wavekey
      , Wavedetailkey
      )

   SELECT DISTINCT
          LOADPLANDETAIL.Loadkey
         ,LOADPLANDETAIL.Orderkey
         ,ISNULL(RTRIM(PICKHEADER.PickHeaderKey),'')
         ,OH.Storerkey
         ,''
         ,WD.Wavekey
         ,WD.WaveDetailKey
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = WD.OrderKey
   JOIN LOADPLANDETAIL  WITH (NOLOCK) ON LOADPLANDETAIL.OrderKey = OH.OrderKey
   LEFT JOIN PICKHEADER WITH (NOLOCK) ON (LOADPLANDETAIL.Loadkey  = PICKHEADER.ExternOrderkey)
                                      AND(LOADPLANDETAIL.Orderkey = PICKHEADER.Orderkey)
   WHERE WD.WaveKey = @c_Wavekey
   GROUP BY LOADPLANDETAIL.Loadkey
         ,  LOADPLANDETAIL.Orderkey
         ,  ISNULL(RTRIM(PICKHEADER.PickHeaderKey),'')
         ,  OH.Storerkey
         ,  WD.Wavekey
         ,  WD.WaveDetailKey
   
   IF @c_PreGenRptData = 'Y'
   BEGIN
      BEGIN TRAN
      -- Uses PickType as a Printed Flag
      UPDATE PICKHEADER WITH (ROWLOCK)
      SET PickType = '1'
         ,EditWho = SUSER_NAME()
         ,EditDate= GETDATE()
         ,TrafficCop = NULL
      FROM PICKHEADER
      JOIN #TMP_PCK ON (PICKHEADER.PickHeaderKey = #TMP_PCK.PickSlipNo)
      WHERE #TMP_PCK.PickSlipNo <> ''

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END

      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      SET @n_NoOfReqPSlip  = 0

      SELECT @n_NoOfReqPSlip = COUNT(1)
      FROM #TMP_PCK
      WHERE PickSlipNo = ''

      IF @n_NoOfReqPSlip > 0
      BEGIN
         EXECUTE nspg_GetKey
                 'PICKSLIP'
               , 9
               , @c_PickSlipNo   OUTPUT
               , @b_Success      OUTPUT
               , @n_Err          OUTPUT
               , @c_Errmsg       OUTPUT
               , 0
               , @n_NoOfReqPSlip

         IF @b_success <> 1
         BEGIN
            SET @n_Continue = 3
            GOTO QUIT_SP
         END

         DECLARE CUR_PSLIP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Orderkey, Loadkey
         FROM #TMP_PCK
         WHERE PickSlipNo = ''
         ORDER BY WaveDetailKey

         OPEN CUR_PSLIP

         FETCH NEXT FROM CUR_PSLIP INTO @c_Orderkey, @c_LoadKey

         WHILE @@FETCH_STATUS <> -1
         BEGIN

            SET @c_PickHeaderKey = 'P' + @c_PickSlipNo

            BEGIN TRAN

            INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
            VALUES (@c_PickHeaderKey, @c_OrderKey, @c_LoadKey, '0', '3', NULL)

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_Continue = 3
               GOTO QUIT_SP
            END

            UPDATE #TMP_PCK
            SET PickSlipNo= @c_PickHeaderKey
            WHERE Loadkey = @c_Loadkey
            AND Orderkey  = @c_Orderkey

            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END

            SET @c_PickSlipNo = RIGHT('000000000' + CONVERT(NVARCHAR(9), CONVERT(INT, @c_PickSlipNo) + 1),9)
            FETCH NEXT FROM CUR_PSLIP INTO @c_Orderkey, @c_LoadKey
         END
         CLOSE CUR_PSLIP
         DEALLOCATE CUR_PSLIP
      END
   END

   DECLARE CUR_PSNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PickSlipNo
         ,OrderKey
         ,Storerkey
   FROM #TMP_PCK
   ORDER BY PickSlipNo
   
   OPEN CUR_PSNO
   
   FETCH NEXT FROM CUR_PSNO INTO @c_PickSlipNo
                                ,@c_Orderkey
                                ,@c_Storerkey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @c_PreGenRptData = 'Y'
      BEGIN
         SET @c_AutoScanIn = '0'
         EXEC nspGetRight
               @c_Facility   = @c_Facility
            ,  @c_StorerKey  = @c_StorerKey
            ,  @c_sku        = ''
            ,  @c_ConfigKey  = 'AutoScanIn'
            ,  @b_Success    = @b_Success    OUTPUT
            ,  @c_authority  = @c_AutoScanIn OUTPUT
            ,  @n_err        = @n_err        OUTPUT
            ,  @c_errmsg     = @c_errmsg     OUTPUT
   
         IF @b_Success = 0
         BEGIN
            SET @n_Continue = 3
            GOTO QUIT_SP
         END
   
         BEGIN TRAN
         IF @c_AutoScanIn = '1'
         BEGIN
            IF NOT EXISTS (SELECT 1
                           FROM PICKINGINFO WITH (NOLOCK)
                           WHERE PickSlipNo = @c_PickSlipNo
                           )
            BEGIN
               INSERT INTO PICKINGINFO  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
               VALUES (@c_PickSlipNo, GETDATE(), SUSER_NAME(), NULL)
   
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SET @n_Continue = 3
                  GOTO QUIT_SP
               END
            END
         END
      END
   
      SET @c_logo = ''
      SET @c_logo = (SELECT TOP 1 itemclass 
                     FROM ORDERDETAIL WITH (NOLOCK) 
                     JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.STORERKEY = SKU.STORERKEY) AND ORDERDETAIL.SKU = SKU.SKU 
                     WHERE ORDERKEY = @c_Orderkey)
   
      SET @c_JCLONG = ''
      SELECT @c_JCLONG = C3.Long
      FROM CODELKUP C3 WITH (NOLOCK)
      WHERE C3.LISTNAME = 'JETCompany' AND C3.Storerkey = @c_StorerKey
      AND C3.CODE = @c_Logo
   
      UPDATE #TMP_PCK
      SET logo = @c_JCLONG
      WHERE PickSlipNo = @c_PickSlipNo
      AND Orderkey = @c_Orderkey
      AND Storerkey = @c_Storerkey
   
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
      FETCH NEXT FROM CUR_PSNO INTO @c_PickSlipNo
                                   ,@c_Orderkey
                                   ,@c_Storerkey
   END
   CLOSE CUR_PSNO
   DEALLOCATE CUR_PSNO

QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_PSLIP') in (0 , 1)
   BEGIN
      CLOSE CUR_PSLIP
      DEALLOCATE CUR_PSLIP
   END

   IF @n_Continue = 3
   BEGIN
      IF @@TRANCOUNT > 0
      BEGIN
         ROLLBACK TRAN
      END
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   IF ISNULL(@c_PreGenRptData,'') = ''
   BEGIN
      INSERT INTO #TMP_PCK66
                 ( PickSlipNo
                 , Contact1
                 , ODUDF03
                 , Loadkey
                 , Orderkey
                 , OrdDate
                 , EditDate
                 , ExternOrderkey
                 , Notes
                 , Loc
                 , Storerkey
                 , SKU
                 , PFUDF01
                 , EMUDF01
                 , Qty
                 , JCLONG
                 , Pageno
                 , RptNotes
                 )
      SELECT #TMP_PCK.PickSlipNo
            ,Contact1 = ISNULL(RTRIM(ORDERS.c_contact1),'')
            ,ODUDF03 = ISNULL(OD.userdefine03,'')
            ,#TMP_PCK.Loadkey
            ,#TMP_PCK.Orderkey
            ,OrdDate   = ORDERS.OrderDate
            ,EditDate   = ORDERS.EditDate
            ,ExternOrderkey = ISNULL(RTRIM(OI.EcomOrderId),'')
            ,Notes   = ISNULL(RTRIM(OD.Notes),'')
            ,PICKDETAIL.Loc
            ,PICKDETAIL.Storerkey
            ,SKU = PICKDETAIL.sku
            ,PFUDF01 = ISNULL(C1.UDF01,'')
            ,EMUDF01 = ISNULL(C2.UDF01,'')
            ,Qty = ISNULL(SUM(PICKDETAIL.Qty),0)
            ,JCLONG = ISNULL(#TMP_PCK.logo,'')
            ,pageno = (Row_number() OVER (PARTITION BY #TMP_PCK.PickSlipNo ORDER BY #TMP_PCK.PickSlipNo,#TMP_PCK.Orderkey,PICKDETAIL.sku asc))/@n_MaxLine
            ,RptNotes = ISNULL(C1.Notes,'')
      FROM #TMP_PCK
      JOIN STORER     WITH (NOLOCK) ON (#TMP_PCK.Storerkey = STORER.Storerkey)
      JOIN ORDERS     WITH (NOLOCK) ON (#TMP_PCK.Orderkey  = ORDERS.Orderkey)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.orderkey = ORDERS.Orderkey
      JOIN PICKDETAIL WITH (NOLOCK) ON (OD.Orderkey    = PICKDETAIL.Orderkey
                                        AND PICKDETAIL.OrderLineNumber = OD.OrderLineNumber)
      JOIN SKU        WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey)
                                    AND(PICKDETAIL.Sku       = SKU.Sku)
      LEFT JOIN ORDERINFO OI WITH (NOLOCK) ON OI.OrderKey = ORDERS.OrderKey
      LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname = 'PLATFORM' AND C1.Storerkey=ORDERS.StorerKey
                                         AND C1.Code =  OI.Platform
      LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON C2.LISTNAME='ECDLMODE'   AND C2.Storerkey=ORDERS.StorerKey
                                         AND C2.Code =  ORDERS.Shipperkey
      WHERE #TMP_PCK.PickSlipNo <> ''
      GROUP BY #TMP_PCK.PickSlipNo
            ,  ISNULL(RTRIM(ORDERS.c_contact1),'')
            ,  ISNULL(OD.userdefine03,'')
            ,  #TMP_PCK.Orderkey
            ,  #TMP_PCK.Loadkey
            ,  ORDERS.OrderDate
            ,  ORDERS.EditDate
            ,  ISNULL(RTRIM(OI.EcomOrderId),'')
            ,  ISNULL(RTRIM(OD.Notes),'')
            ,  PICKDETAIL.Loc
            ,  PICKDETAIL.Storerkey
            ,  PICKDETAIL.sku
            ,  ISNULL(C1.UDF01,'')
            ,  ISNULL(C2.UDF01,'')
            ,  ISNULL(#TMP_PCK.logo,'')
            ,  ISNULL(C1.Notes,'')
      ORDER BY #TMP_PCK.PickSlipNo
              ,PICKDETAIL.sku

      --SELECT @c_MaxPSlipno  = MAX(pickslipno)
      --     , @n_CntRec      = COUNT(1)
      --     , @n_LastPage    = MAX(tp.Pageno)
      --FROM #TMP_PCK66 AS tp
      --GROUP BY tp.PickSlipNo

      --IF @n_CntRec > @n_MaxLine
      --BEGIN
      --   SET @n_ReqLine = @n_MaxLine - (@n_CntRec - @n_MaxLine) - 1
      --END
      --ELSE
      --BEGIN
      --   SET @n_ReqLine = @n_MaxLine - @n_CntRec - 1
      --END

      --IF @n_Continue IN (1,2)
      --BEGIN
      --   INSERT INTO #TMP_PCK66
      --           ( PickSlipNo
      --           , Contact1
      --           , ODUDF03
      --           , Loadkey
      --           , Orderkey
      --           , OrdDate
      --           , EditDate
      --           , ExternOrderkey
      --           , Notes
      --           , Loc
      --           , Storerkey
      --           , SKU
      --           , PFUDF01
      --           , EMUDF01
      --           , Qty
      --           , JCLONG
      --           , Pageno
      --           , RptNotes
      --           )
      --   SELECT TOP 1 @c_MaxPSlipno
      --            , ''
      --            , ''
      --            , Loadkey
      --            , Orderkey
      --            , ''
      --            , ''
      --            , ''
      --            , ''
      --            , ''
      --            , Storerkey
      --            , ''
      --            , ''
      --            , ''
      --            , 0
      --            , ''
      --            , @n_LastPage
      --            , RptNotes
      --   FROM #TMP_PCK66 AS tp
      --   WHERE tp.PickSlipNo= @c_MaxPSlipno
      --   AND tp.Pageno = @n_LastPage

      --   SET @n_ReqLine  = @n_ReqLine - 1
      --END

      SELECT  PickSlipNo    
            , Contact1      
            , ODUDF03       
            , Loadkey       
            , Orderkey      
            , OrdDate       
            , EditDate      
            , ExternOrderkey
            , Notes         
            , Loc           
            , Storerkey     
            , SKU           
            , PFUDF01       
            , EMUDF01       
            , Qty           
            , JCLONG        
            , Pageno        
            , RptNotes      
            , (Row_Number() OVER (PARTITION BY tp.PickSlipNo, tp.Orderkey, tp.Storerkey Order BY TP.PickSlipNo, TP.Pageno ASC)) AS CumSum
      FROM #TMP_PCK66 AS tp
      ORDER BY TP.PickSlipNo,
               --CASE WHEN sku = '' THEN 2 ELSE 1 END,
               TP.Pageno
   END
END  

GO