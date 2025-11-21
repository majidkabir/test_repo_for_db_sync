SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Stored Procedure: isp_packing_list_141_rdt	                        */        
/* CreatiON Date: 10-AUG-2023                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: WZPang                                                   */    
/*                                                                      */    
/* Purpose: WMS-23056 (TW)                                              */      
/*                                                                      */        
/* Called By: r_dw_packing_list_141_rdt	            						*/        
/*                                                                      */        
/* PVCS VersiON: 1.0                                                    */        
/*                                                                      */        
/* VersiON: 7.0                                                         */        
/*                                                                      */        
/* Data ModificatiONs:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author   Ver  Purposes                                  */
/* 10-AUG-2023	 PangWZ	 1.0  Fix Qty									         */
/************************************************************************/        
CREATE   PROC [dbo].[isp_packing_list_141_rdt] (
      @c_PickSlipNo NVARCHAR(10)    
)        
 AS        
 BEGIN        
            
   SET NOCOUNT ON        
   SET ANSI_NULLS ON        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
   SET ANSI_WARNINGS ON        

	DECLARE      
           @n_StartTCnt       INT      
         , @n_Continue        INT      
         , @b_Success         INT      
         , @n_Err             INT      
         , @c_Errmsg          NVARCHAR(255)      
      
         , @n_NoOfReqPSlip    INT      
         , @c_Orderkey        NVARCHAR(10)      
         --, @c_PickSlipNo      NVARCHAR(10)      
         , @c_PickHeaderKey   NVARCHAR(10)      
         , @c_Storerkey       NVARCHAR(15)      
         , @c_GetStorerkey    NVARCHAR(15)      
      
         , @c_AutoScanIn      NVARCHAR(10)      
         , @c_Facility        NVARCHAR(5)      
         , @c_Logo            NVARCHAR(50)      
         , @n_MaxLine         INT      
         , @n_CntRec          INT      
         , @c_MaxPSlipno      NVARCHAR(10)      
         , @n_LastPage        INT      
         , @n_ReqLine         INT      
         , @c_JCLONG          NVARCHAR(255)      
         , @c_RNotes          NVARCHAR(255)      
         , @c_ecomflag        NVARCHAR(50)      
         , @n_MaxLineno       INT      
         , @n_PrnQty          INT      
         , @n_MaxId           INT      
         , @n_MaxRec          INT      
         , @n_CurrentRec      INT      
         , @n_Page            INT      
         , @n_getPageno       INT      
         , @c_recgroup        INT      
         , @c_RptLogo         NVARCHAR(255)      
         , @c_QRCode          NVARCHAR(255)      
         , @c_sku             NVARCHAR(20)      
         , @c_sorting         NVARCHAR(10)     
         , @c_Loadkey         NVARCHAR(10)    
      
   DECLARE      
      
           @C_col01         NVARCHAR(10)      
         , @n_Col01         INT      
         , @c_Col01_Field   NVARCHAR(60)      
         , @n_Col02         INT      
         , @c_Col02_Field   NVARCHAR(60)      
         , @n_Col03         INT      
         , @c_Col03_Field   NVARCHAR(60)      
         , @c_ExecArguments nvarchar(MAX)      
         , @c_output_Field  NVARCHAR(60)      
         , @sql             nvarchar(max)      
      
   SET @n_StartTCnt = @@TRANCOUNT      
   SET @n_Continue  = 1      
   SET @b_Success   = 1      
   SET @n_Err       = 0      
   SET @c_Errmsg    = ''       SET @c_Logo      = ''      
   SET @n_MaxLine   = 9      
   SET @n_CntRec    = 1      
   SET @n_LastPage  = 0      
   SET @n_ReqLine   = 1      
   SET @n_MaxLineno = 8      
   SET @n_PrnQty    = 1      
   SET @n_MaxId     = 1      
   SET @n_MaxRec    = 1      
   SET @n_CurrentRec= 1      
   SET @n_Page      = 1      
   SET @n_getPageno = 1      
   SET @c_recgroup  = 1      
      
   CREATE TABLE #TMP_PCK141_1      
     ( Loadkey      NVARCHAR(10)   NOT NULL      
      , Orderkey     NVARCHAR(10)   NOT NULL      
      , PickSlipNo   NVARCHAR(10)   NOT NULL      
      , Storerkey    NVARCHAR(15)   NOT NULL      
      )      
      
   CREATE TABLE #TMP_PICK141      
      ( rowid             INT NOT NULL identity(1,1) PRIMARY KEY      
      , Orderkey          NVARCHAR(10)   NOT NULL      
      , OrdDate           DATETIME      
      , PickSlipNo        NVARCHAR(10)   NOT NULL      
      , OIPlatform        NVARCHAR(40)      
      , EditDate          DATETIME      
      , Contact1          NVARCHAR(45)   NULL      
      , SKU               NVARCHAR(30)   NULL      
      , RetailSKU         NVARCHAR(20)   NULL      
      , Notes             NVARCHAR(800)  NULL      
      , Qty               INT      
      , CUDF01            NVARCHAR(255)  NULL      
      , PHBarcode         NVARCHAR(100)      
      , OSBarcode         NVARCHAR(100)      
      , EcomOrdIDBarcode  NVARCHAR(100)      
      , RPTLOGO           NVARCHAR(255) NULL      
      , EcomOrdID         NVARCHAR(45) NULL      
      , PLOC              NVARCHAR(10) NULL      
      , SDESCR            NVARCHAR(150) NULL 
      , Notes1            NVARCHAR(800)  NULL          
      , Notes2            NVARCHAR(800)  NULL      
      , ReferenceId       NVARCHAR(20) NULL      
      , SSIZE             NVARCHAR(10) NULL      
      , QRCode            NVARCHAR(250) NULL      
      , RPTTITLE1         NVARCHAR(100) NULL      
      , RPTTITLE2         NVARCHAR(100) NULL      
      , LOTT02            NVARCHAR(18) NULL      
      , ODUDF10           NVARCHAR(50) NULL      
      , Storerkey         NVARCHAR(20) NULL      
      , OTHSKU            NVARCHAR(20) NULL      
      )      
   SELECT @c_Loadkey = Loadkey      
   FROM PACKHEADER (NOLOCK)    
   WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo    
       
   SET @c_Facility = ''      
   SELECT @c_Facility = Facility      
   FROM LOADPLAN WITH (NOLOCK)      
   WHERE Loadkey = @c_Loadkey      
      
   SELECT TOP 1 @c_RptLogo = ISNULL(CL2.Long,''),      
                @c_QRCode  = ISNULL(CL2.UDF01,'')      
   FROM LOADPLANDETAIL LPD (NOLOCK)      
   JOIN ORDERS ORD (NOLOCK) ON LPD.OrderKey = ORD.OrderKey      
   JOIN CODELKUP CL2 WITH (NOLOCK) ON CL2.LISTNAME = 'RPTLogo' AND CL2.Storerkey = ORD.storerkey AND CL2.Code = ORD.OrderGroup      
   WHERE LPD.Loadkey = @c_Loadkey      
      
   INSERT INTO #TMP_PCK141_1      
      ( Loadkey      
      , Orderkey      
      , PickSlipNo      
      , Storerkey      
      )      
      
   SELECT DISTINCT      
          LOADPLANDETAIL.Loadkey      
         ,LOADPLANDETAIL.Orderkey      
         ,ISNULL(RTRIM(PICKHEADER.PickHeaderKey),'')      
         ,ORDERS.Storerkey      
   FROM LOADPLANDETAIL  WITH (NOLOCK)      
   JOIN ORDERS          WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)      
   LEFT JOIN PICKHEADER WITH (NOLOCK) ON (LOADPLANDETAIL.Loadkey  = PICKHEADER.ExternOrderkey)      
                                      AND(LOADPLANDETAIL.Orderkey = PICKHEADER.Orderkey)     
   WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey 
   AND PICKHEADER.PickHeaderKey = @c_PickSlipNo
   GROUP BY LOADPLANDETAIL.Loadkey      
         ,  LOADPLANDETAIL.Orderkey      
         ,  ISNULL(RTRIM(PICKHEADER.PickHeaderKey),'')      
         ,  ORDERS.Storerkey      
      
   BEGIN TRAN      
   -- Uses PickType as a Printed Flag      
   UPDATE PICKHEADER WITH (ROWLOCK)      
   SET PickType = '1'      
      ,EditWho = SUSER_NAME()      
      ,EditDate= GETDATE()      
      ,TrafficCop = NULL      
   FROM PICKHEADER      
   JOIN #TMP_PCK141_1 ON (PICKHEADER.PickHeaderKey = #TMP_PCK141_1.PickSlipNo)      
   WHERE #TMP_PCK141_1.PickSlipNo <> ''      
      
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
   FROM #TMP_PCK141_1      
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
      SELECT Orderkey      
      FROM #TMP_PCK141_1      
      WHERE PickSlipNo = ''      
      ORDER BY Orderkey      
      
      OPEN CUR_PSLIP      
      
      FETCH NEXT FROM CUR_PSLIP INTO @c_Orderkey      
      
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
      
         UPDATE #TMP_PCK141_1      
         SET PickSlipNo= @c_PickHeaderKey      
         WHERE Loadkey = @c_Loadkey      
         AND Orderkey  = @c_Orderkey      
      
         WHILE @@TRANCOUNT > 0      
         BEGIN      
            COMMIT TRAN      
         END      
      
         SET @c_PickSlipNo = RIGHT('000000000' + CONVERT(NVARCHAR(9), CONVERT(INT, @c_PickSlipNo) + 1),9)      
         FETCH NEXT FROM CUR_PSLIP INTO @c_Orderkey      
      END      
      CLOSE CUR_PSLIP      
      DEALLOCATE CUR_PSLIP      
   END      
      
   DECLARE CUR_PSNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT PickSlipNo      
         ,OrderKey      
         ,Storerkey      
   FROM #TMP_PCK141_1      
   ORDER BY PickSlipNo      
      
   OPEN CUR_PSNO      
      
   FETCH NEXT FROM CUR_PSNO INTO @c_PickSlipNo      
                                ,@c_Orderkey      
                                ,@c_Storerkey      
   WHILE @@FETCH_STATUS <> -1      
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
     INSERT INTO #TMP_PICK141    
                 (  Orderkey    
                  , OrdDate
                  , EditDate
                  , Contact1
                  , OIPlatform 
                  , PickSlipNo 
                  , EcomOrdID
                  , ReferenceId 
                  , CUDF01 
                  , SKU    
                  , SDESCR   
                  --, RetailSKU    
                  , Notes    
                  , Qty   
                  , PHBarcode    
                  , OSBarcode    
                  , EcomOrdIDBarcode    
                  , rptlogo  
                  , PLOC    
                  , notes1
                  , notes2  
                  , SSIZE    
                  , QRCode    
                  , RPTTITLE1    
                  , RPTTITLE2    
                  , LOTT02    
                  , ODUDF10    
                  , Storerkey    
                  , OTHSKU    
                 )  
                   
      SELECT  OS.ORDERKEY    
            , OS.OrderDate
            , OS.EditDate 
            , OS.C_CONTACT1
            , ISNULL(CL2.UDF01,'') 
            , t.Pickslipno    
            , OI.Ecomorderid    
            , ISNULL(OI.ReferenceId,'')  
            , ISNULL(CL1.UDF01,'')
            , SKU.sku    
            , SKU.DESCR
            , ISNULL(OD.Notes,'')    
            , SUM(PID.Qty)     
            , dbo.fn_Encode_IDA_Code128 (LTRIM(RTRIM(t.PICKSLIPNO)))    
            , dbo.fn_Encode_IDA_Code128 (LTRIM(RTRIM(OS.ORDERKEY)))    
            , dbo.fn_Encode_IDA_Code128 (LTRIM(RTRIM(OI.Ecomorderid)))    
            , ISNULL(@c_RptLogo,'')  
            , PID.loc     
            , ISNULL(CL3.NOTES,'')    
            , ISNULL(CL4.NOTES,'')   
            , SKU.Size     
            , ISNULL(@c_QRCode,'') AS QRCode 
            , ISNULL(CL5.UDF01,'')    
            , ISNULL(CL5.UDF02,'')  
            , LOTT.lottable02   
            , OD.UserDefine10    
            , t.Storerkey    
            ,  SKU.Sku
           -- , ''
           -- , SKU.RetailSKU    
            --, OD.Userdefine01    
               
      FROM #TMP_PCK141_1 t    
      JOIN ORDERS OS (NOLOCK) ON t.Orderkey = OS.OrderKey    
      LEFT JOIN ORDERINFO OI (NOLOCK) ON OS.ORDERKEY = OI.ORDERKEY    
      JOIN ORDERDETAIL OD(NOLOCK) ON OD.ORDERKEY = OS.ORDERKEY    
      JOIN PICKDETAIL PID (NOLOCk) ON PID.Orderkey = OD.Orderkey AND PID.SKU = OD.SKU AND PID.OrderLineNumber = OD.OrderLineNumber    
      JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.lot = PID.lot and LOTT.sku = PID.SKU AND LOTT.Storerkey = PID.Storerkey    
      JOIN SKU (NOLOCK) ON OD.SKU = SKU.SKU AND OD.STORERKEY = SKU.STORERKEY    
      LEFT JOIN CODELKUP CL1 (NOLOCK) ON OS.STORERKEY = CL1.STORERKEY AND CL1.LISTNAME ='ECDLMODE' and CL1.Code = OS.Shipperkey    
      LEFT JOIN CODELKUP CL2 (NOLOCK) ON OS.STORERKEY = CL2.STORERKEY AND CL2.LISTNAME ='PLATFORM' and CL2.Code = OI.Platform    
      LEFT JOIN CODELKUP CL3 (NOLOCK) ON OS.STORERKEY = CL3.STORERKEY AND CL3.LISTNAME ='REPORTCFG' and CL3.Code= OI.Platform and CL3.Code2 = '01'    
      LEFT JOIN CODELKUP CL4 (NOLOCK) ON OS.STORERKEY = CL4.STORERKEY AND CL4.LISTNAME ='REPORTCFG' and CL4.Code= OI.Platform and CL4.Code2 = '02'    
      LEFT JOIN CODELKUP CL5 (NOLOCK) ON OS.STORERKEY = CL5.STORERKEY AND CL5.LISTNAME ='REPORTCFG' and CL5.Code = '03'    
      WHERE t.PickSlipNo = @c_PickSlipNo    
      GROUP BY OS.ORDERKEY    
            , OS.OrderDate    
            , t.Pickslipno    
            , ISNULL(CL2.UDF01,'')    
            , OS.EditDate    
            , OS.C_CONTACT1    
            , SKU.sku    
            , SKU.DESCR
          --  , OD.Userdefine01    
            , ISNULL(CL3.NOTES,'')    
            , ISNULL(CL1.UDF01,'')    
            , OI.Ecomorderid    
            , PID.Loc    
            , ISNULL(OD.Notes,'')    
            , ISNULL(CL4.NOTES,'')    
            , ISNULL(OI.ReferenceId,'')    
            , SKU.Size    
            , ISNULL(CL5.UDF01,'')    
            , ISNULL(CL5.UDF02,'')    
            , LOTT.lottable02    
            , OD.UserDefine10    
            , t.Storerkey    
      ORDER BY t.Pickslipno    
            ,  OS.ORDERKEY    
            ,  PID.loc    
      
        SET   @C_col01    = ''      
        SET   @n_Col01    = ''      
        SET   @c_Col01_Field  = ''      
        SET   @n_Col02        = ''      
        SET   @c_Col02_Field  = ''      
        SET   @n_Col03        = ''      
        SET   @c_Col03_Field  = ''      
        SET   @c_GetStorerkey  = ''      
      
      SELECT TOP 1 @c_GetStorerkey = t.Storerkey      
      FROM #TMP_PCK141_1 t      
      Where Loadkey = @c_Loadkey      
            
      SELECT      
                  @n_Col01      = ISNULL(MAX(CASE WHEN Code = 'Col01' THEN 1 ELSE 0 END),0)      
               ,  @c_Col01_Field= ISNULL(MAX(CASE WHEN Code = 'Col01' THEN UDF02 ELSE '' END),'')      
               ,  @n_Col02      = ISNULL(MAX(CASE WHEN Code = 'Col02' THEN 1 ELSE 0 END),0)      
               ,  @c_Col02_Field= ISNULL(MAX(CASE WHEN Code = 'Col02' THEN UDF02 ELSE '' END),'')      
               ,  @n_Col03      = ISNULL(MAX(CASE WHEN Code = 'Col03' THEN 1 ELSE 0 END),0)      
               ,  @c_Col03_Field= ISNULL(MAX(CASE WHEN Code = 'Col03' THEN UDF02 ELSE '' END),'')      
            FROM CODELKUP WITH (NOLOCK)      
            WHERE ListName = 'REPORTCFG'      
            AND   Storerkey = @c_GetStorerkey      
            AND   Long = 'r_dw_print_pickorder141'      
            AND   ISNULL(Short,'') <> 'N'      
        
            
      IF EXISTS(SELECT LONG FROM CODELKUP(NOLOCK) WHERE LISTNAME = 'REPORTCFG' AND CODE = 'SortByLogicalPlatform'       
                      AND STORERKEY = @c_GetStorerkey AND Code2 = 'r_dw_packing_list_141_rdt')      
      BEGIN      
       SET @c_sorting = 'Y'      
      END      
      ELSE       
      BEGIN      
         SET @c_sorting = 'N'      
      END      
            
      
   IF @c_sorting = 'Y'      
      SELECT  Orderkey      
            , OrdDate      
            , PickSlipNo      
            , OIPlatform      
            , EditDate      
            , Contact1      
            , SKU      
            , RetailSKU      
            , Notes      
            , Qty      
            , CUDF01      
            , PHBarcode      
            , OSBarcode      
            , EcomOrdIDBarcode      
            , RptLogo      
            , EcomOrdID      
            , PLOC      
            , SDESCR  
            , notes1
            , Notes2      
            , ReferenceId      
            , SSIZE      
            , QRCode      
            , RPTTITLE1      
            , RPTTITLE2      
            , LOTT02      
            , ODUDF10      
            , storerkey      
            , OTHSKU      
      FROM #TMP_PICK141      
      ORDER BY OIPlatform,PickSlipNo,Orderkey,PLOC      
   ELSE       
      SELECT  Orderkey      
            , OrdDate      
            , PickSlipNo      
            , OIPlatform      
            , EditDate      
            , Contact1      
            , SKU      
            , RetailSKU      
            , Notes      
            , Qty      
            , CUDF01      
            , PHBarcode      
            , OSBarcode      
            , EcomOrdIDBarcode      
            , RptLogo      
            , EcomOrdID      
            , PLOC      
            , SDESCR  
            , notes1
            , Notes2      
            , ReferenceId      
            , SSIZE      
            , QRCode      
            , RPTTITLE1      
            , RPTTITLE2      
            , LOTT02      
            , ODUDF10      
            , storerkey      
            , OTHSKU      
      FROM #TMP_PICK141      
      ORDER BY PickSlipNo,Orderkey,PLOC      
      
      
      
QUIT_RESULT:      
END -- procedure      
      
SET QUOTED_IDENTIFIER OFF 

GO