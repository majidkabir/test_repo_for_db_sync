SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_GetPickSlipOrders110                                */  
/* Creation Date: 01-APR-2020                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS - 12589 - [PH] - Addidas Picking List                   */  
/*        :                                                             */  
/* Called By:r_dw_print_pickorder110                                    */  
/*          :                                                           */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 26-Jun-2020  CSCHONG   1.1 WMS-12589 revised field mapping (CS01)    */
/************************************************************************/  
CREATE PROC [dbo].[isp_GetPickSlipOrders110]
            @c_Sourcekey   NVARCHAR(10)  
         ,  @c_Sourcetype  NVARCHAR(10) = ''  
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
         , @c_Loadkey         NVARCHAR(10)  
         , @c_Orderkey        NVARCHAR(10)  
         , @c_OrderGroup      NVARCHAR(20)  
         , @c_PickSlipNo      NVARCHAR(10)  
         , @c_PickHeaderKey   NVARCHAR(10)  
         , @c_ExtOrderkey     NVARCHAR(50) 
  
         , @c_ConsoOrderkey   NVARCHAR(30)  
         , @c_CCompany        NVARCHAR(45)  
         , @c_CSCompanies     NVARCHAR(400)  
  
         , @c_SortLocType     NVARCHAR(10)     
         , @c_PickZone        NVARCHAR(10)  
         , @c_PickType        NVARCHAR(10)  
         , @c_LocationType    NVARCHAR(10)  
         , @c_LogicalLocation NVARCHAR(10)  
         , @c_Storerkey       NVARCHAR(15)  
         , @c_Sku             NVARCHAR(20)  
         , @c_SkuDescr        NVARCHAR(60)  
         , @c_Loc             NVARCHAR(10)  
         , @c_ID              NVARCHAR(20)  
         , @n_Qty             INT  
         , @n_QtyInPLT        INT  
         , @n_QtyInCS         INT  
         , @n_QtyInEA         INT  
         , @n_QtyRemain       INT  
         , @c_Lot02Label      NVARCHAR(20)  
         , @c_Lot04Label      NVARCHAR(20)  
         , @c_Lottable01      NVARCHAR(18)  
         , @c_Lottable10      NVARCHAR(30)  
         , @n_Pallet          FLOAT  
         , @n_CaseCnt         FLOAT
         , @n_PQty            INT
         , @n_lliqty          INT
         , @n_CntPLOC         INT
         , @n_Cntlliloc       INT      
         , @n_qtypicked       INT           --(CS01)         
  
         , @c_PrintedFlag     CHAR(1)  
  
         , @c_PickDetailKey   NVARCHAR(10)  
         , @c_OrderLineNumber NVARCHAR(5)  
  
         , @n_PageNo          INT  
         , @n_PageGroup       INT  
         , @n_RowPerPage      FLOAT  
  
         , @n_ShowTotalCases     INT = 0       --WL01  
         , @n_ShowGrandTotal     INT = 0       --WL01  
         , @c_GetStorerkey       NVARCHAR(20)  --WL01  
         , @n_TotalCases         INT = 0       --WL01  
         , @n_TotalQty           INT = 0       --WL01  
         , @c_GetPickdetailkey   NVARCHAR(10) = '' --WL02  
         , @n_LinkPickdetailkey  INT = 0           --WL02  
         , @n_FilterByOrderGroup INT = 0           --WL02  
  
   SET @n_StartTCnt= @@TRANCOUNT  
   SET @n_Continue = 1  
   SET @b_Success  = 1  
   SET @n_Err      = 0  
   SET @c_Errmsg   = ''  
   SET @n_RowPerPage = 20.00  
  
   WHILE @@TRANCOUNT > 0   
   BEGIN  
      COMMIT TRAN  
   END   
  
      CREATE TABLE #TMP_PCK110  
      ( PickSlipNo      NVARCHAR(10)   NOT NULL DEFAULT('')  
      , PrintedFlag     CHAR(1)        NOT NULL DEFAULT('N') 
      , Loadkey         NVARCHAR(10)   NOT NULL  
      , Orderkey        NVARCHAR(20)   NOT NULL
      , CCompany        NVARCHAR(45)   NOT NULL DEFAULT('')  
      , consoOrderkey   NVARCHAR(50)   NOT NULL  
      , PickType        NVARCHAR(10)   NOT NULL  
      , ExtOrderkey     NVARCHAR(50)   NOT NULL  
      , Storerkey       NVARCHAR(15)   NOT NULL  
      , Sku             NVARCHAR(20)   NOT NULL  
      , LogicalLocation NVARCHAR(10)   NOT NULL DEFAULT('')  
      , Loc             NVARCHAR(10)   NOT NULL  
      , ID              NVARCHAR(18)   NOT NULL DEFAULT('')   
      , LocationType    NVARCHAR(10)   NOT NULL DEFAULT('') 
      , Lottable01      NVARCHAR(18)   NOT NULL DEFAULT(0)     
      , Lottable10      NVARCHAR(30)       NULL  
      , QtyPicked       INT                                --(CS01) 
      )  
  
  
      SELECT @c_GetStorerkey = OH.Storerkey  
      FROM ORDERS     OH WITH (NOLOCK)  
      WHERE OH.Loadkey = @c_Sourcekey  

      DECLARE CUR_LOADORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT   
             Loadkey  
            ,Orderkey  
            ,Storerkey  
      FROM ORDERS WITH (NOLOCK)  
      WHERE Loadkey = @c_Sourcekey  
      ORDER BY orderkey  

   SELECT @n_ShowTotalCases    = ISNULL(MAX(CASE WHEN Code = 'ShowTotalCases' THEN 1 ELSE 0 END),0)    
         ,@n_ShowGrandTotal    = ISNULL(MAX(CASE WHEN Code = 'ShowGrandTotal' THEN 1 ELSE 0 END),0)    
         ,@n_LinkPickdetailkey = ISNULL(MAX(CASE WHEN Code = 'LinkPickdetailkey' THEN 1 ELSE 0 END),0)   
         ,@n_FilterByOrderGroup = ISNULL(MAX(CASE WHEN Code = 'FilterByOrderGroup' THEN 1 ELSE 0 END),0) 
   FROM CODELKUP WITH (NOLOCK)    
   WHERE ListName = 'REPORTCFG'    
   AND   Storerkey= @c_GetStorerkey    
   AND   Long = 'r_dw_print_pickorder110'    
   AND   ISNULL(Short,'') <> 'N'    
     
   OPEN CUR_LOADORD  
     
   FETCH NEXT FROM CUR_LOADORD INTO @c_Loadkey,@c_Orderkey, @c_Storerkey  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  

      DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT LOC.LogicalLocation  
            ,LOC.LocationType   
            ,PD.Storerkey  
            ,PD.Sku   
            ,PD.Loc  
            ,PD.ID   
            ,Lottable01 = ISNULL(RTRIM(LA.Lottable01),'')  
            ,Lottable10 =ISNULL(RTRIM(LA.Lottable10),'') 
            ,ISNULL(OH.c_company,'')
            ,OH.ExternOrderkey
            ,SUM(PD.qty)                                          --CS01
      FROM ORDERS       OH    WITH (NOLOCK)   
      JOIN PICKDETAIL   PD    WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)  
      JOIN LOC          LOC   WITH (NOLOCK) ON (PD.Loc = LOC.Loc)  
      JOIN SKU          SKU   WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)  
                                            AND(PD.Sku = SKU.Sku)  
      JOIN PACK         PCK   WITH (NOLOCK) ON (SKU.Packkey = PCK.Packkey)  
      JOIN LOTATTRIBUTE LA    WITH (NOLOCK) ON (PD.Lot = LA.Lot)  
      WHERE OH.Orderkey  = @c_orderkey  
      AND   OH.Storerkey= @c_Storerkey  
      GROUP BY LOC.LogicalLocation  
            ,  LOC.PickZone  
            ,  LOC.LocationType  
            ,  PD.Storerkey  
            ,  PD.Sku  
            ,  PD.Loc  
            ,  PD.ID  
            ,  ISNULL(RTRIM(LA.Lottable01),'')  
            ,  ISNULL(RTRIM(LA.Lottable10),'')  
            ,  OH.C_Company
            ,  OH.ExternOrderkey
      ORDER BY LOC.LocationType  
              ,LOC.LogicalLocation  
              ,PD.Loc  
              ,PD.ID
              ,PD.Storerkey  
              ,PD.Sku  
              
      OPEN CUR_PICK  
     
      FETCH NEXT FROM CUR_PICK INTO   @c_LogicalLocation  
                                    , @c_LocationType   
                                    , @c_Storerkey  
                                    , @c_Sku  
                                    , @c_Loc  
                                    , @c_ID  
                                    , @c_Lottable01  
                                    , @c_Lottable10  
                                    , @c_CCompany  
                                    , @c_ExtOrderkey  
                                    , @n_qtypicked                       --CS01                       
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  

       SET @n_Cntlliloc = 0
       SET @n_CntPLOC = 0

       SET @n_PQty = 0
       SET @n_lliqty = 0

       SET @c_PickType = ''
       SET @c_ConsoOrderkey = ''


       SELECT @n_CntPLOC = COUNT(1)
             ,@n_PQty = SUM(PD.qty)
       FROM PICKDETAIL PD (nolock)
       WHERE PD.orderkey = @c_Orderkey
       AND PD.loc = @c_loc
       AND PD.id = @c_id

        SELECT @n_CntlliLOC = COUNT(1)
             ,@n_lliQty = SUM(lli.qty)
       FROM LOTxLOCXID lli (nolock)
       WHERE lli.loc = @c_loc
       AND lli.id = @c_id
       AND lli.qty <> 0

       IF @n_CntPLOC = @n_CntlliLOC
       BEGIN
         IF @n_PQty = @n_lliQty
         BEGIN
           SET @c_PickType = 'FP'
         END
         ELSE IF  @n_PQty > @n_lliQty
         BEGIN
           SET  @c_PickType = 'CP'
         END
       END
       ELSE
       BEGIN
         SET  @c_PickType = 'CP'
       END
  
            SET @c_ConsoOrderkey =  RTRIM(@c_PickType) + RTRIM(@c_Orderkey)
  
            INSERT INTO #TMP_PCK110  
               ( Loadkey    
               , CCompany  
               , consoOrderkey   
               , Orderkey  
               , ExtOrderkey  
               , PickType   
               , LocationType  
               , LogicalLocation  
               , Storerkey  
               , Sku   
               , Loc  
               , ID                             
               , Lottable01  
               , Lottable10  
               , QtyPicked                    --CS01    
               )  
            VALUES   
               ( @c_Loadkey    
               , @c_CCompany     
               , @c_ConsoOrderkey  
               , @c_Orderkey 
               , @c_extOrderkey
               , @c_PickType   
               , @c_LocationType  
               , @c_LogicalLocation  
               , @c_Storerkey  
               , @c_Sku   
               , @c_Loc  
               , @c_ID                              
               , @c_Lottable01  
               , @c_Lottable10    
               , @n_qtypicked                    --CS01       
               )  

         FETCH NEXT FROM CUR_PICK INTO    @c_LogicalLocation  
                                        , @c_LocationType   
                                        , @c_Storerkey  
                                        , @c_Sku  
                                        , @c_Loc  
                                        , @c_ID  
                                        , @c_Lottable01  
                                        , @c_Lottable10  
                                        , @c_CCompany  
                                        , @c_ExtOrderkey  
                                        , @n_qtypicked                       --CS01  
      END                              
      CLOSE CUR_PICK  
      DEALLOCATE CUR_PICK  
  
   FETCH NEXT FROM CUR_LOADORD INTO @c_Loadkey, @c_Orderkey, @c_Storerkey   
   END  
   CLOSE CUR_LOADORD  
   DEALLOCATE CUR_LOADORD  

   IF NOT EXISTS (SELECT 1  
                  FROM #TMP_PCK110 
               )  
   BEGIN  
      GOTO QUIT_SP  
   END  
     
   SET @n_NoOfReqPSlip  = 0  
  
   SELECT @n_NoOfReqPSlip = COUNT(DISTINCT TPK.Loadkey + TPK.Orderkey + TPK.PickType)  
   FROM #TMP_PCK110 TPK  
   WHERE NOT EXISTS ( SELECT 1  
                      FROM PICKHEADER PH WITH (NOLOCK)   
                      WHERE PH.ExternOrderKey =  TPK.Loadkey   
                      AND PH.Orderkey = TPK.OrderKey  
                      AND PH.consoorderkey = TPK.consoOrderkey
                    )  
  
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
   END  
  
   DECLARE CUR_PSLIP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT  
          TPK.Loadkey  
         ,TPK.Orderkey  
         ,TPK.PickType   
         ,TPK.ConsoOrderkey  
         ,PickHeaderkey = ISNULL(RTRIM(PH.PickHeaderKey),'')  
   FROM #TMP_PCK110 TPK  
   LEFT JOIN PICKHEADER PH WITH (NOLOCK) ON (TPK.Loadkey = PH.ExternOrderKey)  
                                         AND(TPK.ConsoOrderkey = PH.ConsoOrderKey)
                               AND(TPK.Orderkey = PH.Orderkey)   
   ORDER BY TPK.Loadkey  
         ,  TPK.Orderkey  
         ,  TPK.PickType  desc
         ,  TPK.ConsoOrderkey  
         ,  ISNULL(RTRIM(PH.PickHeaderKey),'')  
  
   OPEN CUR_PSLIP  
     
   FETCH NEXT FROM CUR_PSLIP INTO @c_Loadkey  
                                 ,@c_Orderkey 
                                 ,@c_PickType  
                                 ,@c_ConsoOrderkey  
                                 ,@c_PickHeaderKey  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      BEGIN TRAN  
      IF @c_PickHeaderKey = ''  
      BEGIN  
         SET @c_PickHeaderKey = 'P' + @c_PickSlipNo  
  
         INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, loadkey,TrafficCop,consoorderkey)  
         VALUES (@c_PickHeaderKey, @c_LoadKey, @c_Orderkey, '0', 'LB',@c_LoadKey, NULL,@c_ConsoOrderkey)  
  
         SET @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN  
            SET @n_Continue = 3  
            GOTO QUIT_SP  
         END  
  
         SET @c_PickSlipNo = RIGHT('000000000' + CONVERT(NVARCHAR(9), CONVERT(INT, @c_PickSlipNo) + 1),9)  
  
         SET @c_PrintedFlag = 'N'  
      END  
      ELSE  
      BEGIN  
         UPDATE PICKHEADER WITH (ROWLOCK)  
         SET PickType = '1'  
            ,EditWho = SUSER_NAME()  
            ,EditDate= GETDATE()  
            ,TrafficCop = NULL  
         FROM PICKHEADER  
         WHERE PickHeaderKey = @c_PickHeaderKey  
  
         SET @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN  
            SET @n_Continue = 3  
            GOTO QUIT_SP  
         END  
  
         SET @c_PrintedFlag = 'Y'  
      END  
  
      DECLARE CUR_PD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT   
              PD.PickDetailKey  
            , PD.Orderkey  
            , PD.OrderLineNumber  
            , TPK.PickType   
      FROM #TMP_PCK110 TPK  
      JOIN ORDERS     OH   WITH (NOLOCK) ON (TPK.Loadkey  = OH.Loadkey)  
      JOIN PICKDETAIL PD   WITH (NOLOCK) ON (OH.Orderkey  = PD.Orderkey)  
                                         AND(TPK.Storerkey= PD.Storerkey)  
                                         AND(TPK.Sku = PD.Sku)  
                                         AND(TPK.Loc = PD.Loc)  
                                         AND(TPK.ID  = PD.ID)  
                                       --  AND(TPK.Pickdetailkey = CASE WHEN @n_LinkPickdetailkey = 1 THEN PD.PickDetailKey ELSE TPK.Pickdetailkey END )     
      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (PD.Lot = LA.Lot)  
                                         AND(ISNULL(RTRIM(TPK.Lottable01),'') = ISNULL(RTRIM(LA.Lottable01),''))  
                               AND(ISNULL(RTRIM(TPK.Lottable10),'') = ISNULL(RTRIM(LA.Lottable10),''))
                                        -- AND(ISNULL(RTRIM(TPK.Lottable04),'1900-01-01') = ISNULL(RTRIM(LA.Lottable04),'1900-01-01'))  
      JOIN LOC         LOC WITH (NOLOCK) ON (TPK.Loc  = LOC.Loc)  
                                         AND(TPK.LocationType = LOC.LocationType)  
                                       --  AND(TPK.PickZone = LOC.PickZone)  
      WHERE TPK.Loadkey = @c_Loadkey  
      AND   TPK.ConsoOrderkey = @c_ConsoOrderkey  
      ORDER BY PD.PickDetailKey  
  
      OPEN CUR_PD  
     
      FETCH NEXT FROM CUR_PD INTO @c_PickDetailkey  
                                 ,@c_Orderkey  
                                 ,@c_OrderLineNumber  
                                 ,@c_PickType  
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         IF @c_PickType = 'FP' AND @n_Qty < @n_Pallet   
         BEGIN  
            GOTO NEXT_PD  
         END  
  
         IF @c_PickType IN ( 'PPFC', 'FC') AND @n_Qty < @n_CaseCnt  
         BEGIN  
            GOTO NEXT_PD  
         END  
           
         IF @c_PickType IN ( 'PPLC', 'LC') AND @n_Qty >= @n_CaseCnt  
         BEGIN  
            GOTO NEXT_PD  
         END  
  
         IF EXISTS ( SELECT 1  
                     FROM REFKEYLOOKUP WITH (NOLOCK)  
                     WHERE Pickdetailkey = @c_PickDetailKey  
                  )  
         BEGIN  
            UPDATE REFKEYLOOKUP WITH (ROWLOCK)  
            SET PickSlipNo = @c_PickHeaderKey  
               ,EditWho = SUSER_NAME()  
               ,EditDate= GETDATE()  
               ,ArchiveCop = NULL  
            WHERE PickDetailKey = @c_PickDetailKey  
            AND PickSlipNo <> @c_PickHeaderKey  
         END  
         ELSE  
         BEGIN  
            INSERT INTO REFKEYLOOKUP (Pickdetailkey, Pickslipno, Orderkey, OrderLineNumber, Loadkey)  
            VALUES (@c_PickDetailkey, @c_PickHeaderKey, @c_OrderKey, @c_OrderLineNumber, @c_loadkey)  
         END  
  
         SET @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN  
            SET @n_Continue = 3  
            GOTO QUIT_SP  
         END  
  
         IF EXISTS ( SELECT 1  
                     FROM PICKDETAIL WITH (NOLOCK)  
                     WHERE PickDetailKey = @c_PickDetailKey  
                     AND PickSlipNo <> @c_PickHeaderKey  
                    )  
         BEGIN  
            UPDATE PICKDETAIL WITH (ROWLOCK)  
            SET PickSlipNo = @c_PickHeaderKey  
               ,EditWho = SUSER_NAME()  
               ,EditDate= GETDATE()  
               ,ArchiveCop = NULL  
            WHERE PickDetailKey = @c_PickDetailKey  
  
            SET @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN  
               SET @n_Continue = 3  
               GOTO QUIT_SP  
            END  
         END  
         NEXT_PD:  
         FETCH NEXT FROM CUR_PD INTO @c_PickDetailkey  
                                    ,@c_Orderkey  
                                    ,@c_OrderLineNumber  
                                    ,@c_PickType  
      END  
      CLOSE CUR_PD  
      DEALLOCATE CUR_PD  
  
      UPDATE #TMP_PCK110  
      SET PickSlipNo  = @c_PickHeaderKey  
         ,PrintedFlag = @c_PrintedFlag  
      WHERE Loadkey   = @c_Loadkey 
      AND Orderkey = @c_orderkey 
      AND ConsoOrderkey  = @c_ConsoOrderkey  
  
      WHILE @@TRANCOUNT > 0   
      BEGIN  
         COMMIT TRAN  
      END  
            
      FETCH NEXT FROM CUR_PSLIP INTO @c_Loadkey  
                                    ,@c_Orderkey 
                                    ,@c_PickType  
                                    ,@c_ConsoOrderkey  
                                    ,@c_PickHeaderKey  
  
   END  
   CLOSE CUR_PSLIP  
   DEALLOCATE CUR_PSLIP   
  
QUIT_SP:  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_LOADORD') in (0 , 1)    
   BEGIN  
      CLOSE CUR_LOADORD  
      DEALLOCATE CUR_LOADORD  
   END  
  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_PSLIP') in (0 , 1)    
   BEGIN  
      CLOSE CUR_PSLIP  
      DEALLOCATE CUR_PSLIP  
   END  
  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_PICK') in (0 , 1)    
   BEGIN  
      CLOSE CUR_PICK  
      DEALLOCATE CUR_PICK  
   END  
  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_PD') in (0 , 1)    
   BEGIN  
      CLOSE CUR_PD  
      DEALLOCATE CUR_PD  
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
  
   WHILE @@TRANCOUNT < @n_StartTCnt     BEGIN  
      BEGIN TRAN  
   END  

   SELECT        PickSlipNo
               , PrintedFlag
               , Loadkey   
               , Orderkey  
               , CCompany  
               , consoOrderkey   
               , PickType
               , ExtOrderkey  
               , Storerkey  
               , substring(Sku,1,6) as sku   
               , LogicalLocation  
               , Loc  
               , ID        
               , LocationType                      
               , Lottable01  
               , Lottable10
               , sum(QtyPicked)                    --CS01    
   FROM  #TMP_PCK110
   group by PickSlipNo
               , PrintedFlag 
               ,Loadkey    
               , CCompany  
               , consoOrderkey   
               , Orderkey  
               , ExtOrderkey  
               , PickType   
               , LocationType  
               , LogicalLocation  
               , Storerkey  
               , substring(Sku,1,6)    
               , Loc  
               , ID                             
               , Lottable01  
               , Lottable10
              -- , QtyPicked                    --CS01
   order by pickslipno,LogicalLocation,loc
END -- procedure  

GO