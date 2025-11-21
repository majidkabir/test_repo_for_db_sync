SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_GetPickSlipOrders117                                */  
/* Creation Date: 12-MAR-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: copy from isp_GetPickSlipOrders68                        */  
/*                                                                      */  
/* Purpose: WMS - 16522 - Huhtamaki_Consolidated_Picklist_CR            */  
/*        :                                                             */  
/* Called By:r_dw_print_pickorder117                                    */  
/*          :                                                           */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */
/* 12-Mar-2021  mingle01  1.1 Add new mapping                           */
/************************************************************************/  
CREATE PROC [dbo].[isp_GetPickSlipOrders117]  
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
  
         , @c_ConsoOrderkey   NVARCHAR(30)  
         , @c_CSCompany       NVARCHAR(45)  
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
         , @c_Lottable02      NVARCHAR(18)  
         , @dt_Lottable04     DATETIME  
         , @n_Pallet          FLOAT  
         , @n_CaseCnt         FLOAT  
  
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
         , @c_Lottable01      NVARCHAR(18)     --mingle01 
         , @dt_Lottable13     DATETIME         --mingle01
  
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
  
      CREATE TABLE #TMP_PCK  
      ( Loadkey         NVARCHAR(10)   NOT NULL  
      , PickSlipNo      NVARCHAR(10)   NOT NULL DEFAULT('')  
      , PrintedFlag     CHAR(1)        NOT NULL DEFAULT('N')  
      , CSCompanies     NVARCHAR(400)  NOT NULL DEFAULT('')  
      , ConsoOrderkey   NVARCHAR(30)   NOT NULL  
      , OrderGroup      NVARCHAR(20)   NOT NULL  
      , SortLocType     NVARCHAR(10)   NOT NULL DEFAULT('')  
      , PickType        NVARCHAR(10)   NOT NULL  
      , PickZone        NVARCHAR(10)   NOT NULL  
      , LocationType    NVARCHAR(10)   NOT NULL DEFAULT('')  
      , LogicalLocation NVARCHAR(10)   NOT NULL DEFAULT('')  
      , Storerkey       NVARCHAR(15)   NOT NULL  
      , Sku             NVARCHAR(20)   NOT NULL  
      , SkuDescr        NVARCHAR(60)   NOT NULL DEFAULT('')  
      , Loc             NVARCHAR(10)   NOT NULL  
      , ID              NVARCHAR(18)   NOT NULL DEFAULT('')  
      , Pallet          FLOAT          NOT NULL DEFAULT(0.00)  
      , CaseCnt         FLOAT          NOT NULL DEFAULT(0.00)     
      , Qty             INT            NOT NULL DEFAULT(0)  
      , QtyInPLT        INT            NOT NULL DEFAULT(0)  
      , QtyInCS         INT            NOT NULL DEFAULT(0)  
      , QtyInEA         INT            NOT NULL DEFAULT(0)  
      , Lot02Label      NVARCHAR(20)   NOT NULL DEFAULT('')   
      , Lot04Label      NVARCHAR(20)   NOT NULL DEFAULT('')    
      , Lottable02      NVARCHAR(18)   NOT NULL DEFAULT(0)     
      , Lottable04      DATETIME       NULL  
      , TotalCases      INT            NULL     --WL01  
      , Pickdetailkey   NVARCHAR(10)   NULL     --WL02
      , Lottable01      NVARCHAR(18)   NOT NULL DEFAULT(0)     --mingle01     
      , Lottable13      DATETIME       NULL                    --mingle01
      )  
  
   CREATE TABLE #TMP_PKPAGE  
      ( RowNo           INT IDENTITY(1,1)  NOT NULL         PRIMARY KEY     
      , PageGroup       INT            NOT NULL DEFAULT(0)  
      --, PageNo          INT            NOT NULL DEFAULT(0)  
      , Loadkey         NVARCHAR(10)   NOT NULL  
      , PickSlipNo      NVARCHAR(10)   NOT NULL DEFAULT('')  
      , PrintedFlag     CHAR(1)        NOT NULL DEFAULT('N')  
      , CSCompanies     NVARCHAR(400)  NOT NULL DEFAULT('')  
      , ConsoOrderkey   NVARCHAR(30)   NOT NULL  
      , OrderGroup      NVARCHAR(20)   NOT NULL  
      , SortLocType     NVARCHAR(10)   NOT NULL DEFAULT('')  
      , PickType        NVARCHAR(10)   NOT NULL  
      , PickTypeDescr   NVARCHAR(20)   NOT NULL  
      , PickZone        NVARCHAR(10)   NOT NULL  
      , LocationType    NVARCHAR(10)   NOT NULL DEFAULT('')  
      , LogicalLocation NVARCHAR(10)   NOT NULL DEFAULT('')  
      , Storerkey       NVARCHAR(15)   NOT NULL  
      , Sku             NVARCHAR(20)   NOT NULL  
      , SkuDescr        NVARCHAR(60)   NOT NULL DEFAULT('')  
      , Loc             NVARCHAR(10)   NOT NULL  
      , ID              NVARCHAR(18)   NOT NULL DEFAULT('')  
      , Pallet          FLOAT          NOT NULL DEFAULT(0.00)  
      , CaseCnt         FLOAT          NOT NULL DEFAULT(0.00)     
      , Qty             INT            NOT NULL DEFAULT(0)  
      , QtyInPLT        INT            NOT NULL DEFAULT(0)  
      , QtyInCS         INT            NOT NULL DEFAULT(0)  
      , QtyInEA         INT            NOT NULL DEFAULT(0)  
      , Lot02Label      NVARCHAR(20)   NOT NULL DEFAULT('')   
      , Lot04Label    NVARCHAR(20)   NOT NULL DEFAULT('')    
      , Lottable02      NVARCHAR(18)   NOT NULL DEFAULT(0)     
      , Lottable04      DATETIME       NULL  
      , TotalCases      INT            NULL     --WL01  
      , Pickdetailkey   NVARCHAR(10)   NULL     --WL02
      , Lottable01      NVARCHAR(18)   NOT NULL DEFAULT(0)      --mingle01    
      , Lottable13      DATETIME       NULL                     --mingle01
      )  
  
 CREATE TABLE #TMP_PAGING  
      ( RowNo           INT IDENTITY(1,1)  NOT NULL         PRIMARY KEY     
      , PageGroup       INT            NOT NULL DEFAULT(0)  
      , PageNo          INT            NOT NULL DEFAULT(0)  
      , Loadkey         NVARCHAR(10)   NOT NULL  
      , PickSlipNo      NVARCHAR(10)   NOT NULL DEFAULT('')  
      , OrderGroup      NVARCHAR(20)   NOT NULL  
      , SortLocType     NVARCHAR(10)   NOT NULL DEFAULT('')  
      , PickType        NVARCHAR(10)   NOT NULL  
      , PickZone        NVARCHAR(10)   NOT NULL  
      )  
  
   IF @c_Sourcetype = 'WP'  
   BEGIN  
      --WL01 Start  
      SELECT @c_GetStorerkey = OH.Storerkey  
      FROM ORDERS     OH WITH (NOLOCK)  
      JOIN WAVEDETAIL WD WITH (NOLOCK) ON (OH.Orderkey = WD.Orderkey)  
      WHERE WD.Wavekey = @c_Sourcekey  
      --WL01 End  
  
      DECLARE CUR_LOADORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT   
             OH.Loadkey  
            ,OH.OrderGroup  
            ,OH.Storerkey  
      FROM ORDERS     OH WITH (NOLOCK)  
      JOIN WAVEDETAIL WD WITH (NOLOCK) ON (OH.Orderkey = WD.Orderkey)  
      WHERE WD.Wavekey = @c_Sourcekey  
      AND   OH.Loadkey <> ''   
      ORDER BY OH.Loadkey  
             , OH.OrderGroup  
   END  
   ELSE  
   BEGIN  
      --WL01 Start  
      SELECT @c_GetStorerkey = OH.Storerkey  
      FROM ORDERS     OH WITH (NOLOCK)  
      WHERE OH.Loadkey = @c_Sourcekey  
      --WL01 End  
  
      DECLARE CUR_LOADORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT   
             Loadkey  
            ,OrderGroup  
            ,Storerkey  
      FROM ORDERS WITH (NOLOCK)  
      WHERE Loadkey = @c_Sourcekey  
      ORDER BY OrderGroup  
   END  
  
   --WL01 Start  
   SELECT @n_ShowTotalCases    = ISNULL(MAX(CASE WHEN Code = 'ShowTotalCases' THEN 1 ELSE 0 END),0)    
         ,@n_ShowGrandTotal    = ISNULL(MAX(CASE WHEN Code = 'ShowGrandTotal' THEN 1 ELSE 0 END),0)    
         ,@n_LinkPickdetailkey = ISNULL(MAX(CASE WHEN Code = 'LinkPickdetailkey' THEN 1 ELSE 0 END),0)    --WL02  
         ,@n_FilterByOrderGroup = ISNULL(MAX(CASE WHEN Code = 'FilterByOrderGroup' THEN 1 ELSE 0 END),0)  --WL02  
   FROM CODELKUP WITH (NOLOCK)    
   WHERE ListName = 'REPORTCFG'    
   AND   Storerkey= @c_GetStorerkey    
   AND   Long = 'r_dw_print_pickorder117'    
   AND   ISNULL(Short,'') <> 'N'    
   --WL01 End  
     
   OPEN CUR_LOADORD  
     
   FETCH NEXT FROM CUR_LOADORD INTO @c_Loadkey,@c_OrderGroup, @c_Storerkey  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      SET @c_CSCompanies = ''  
  
      DECLARE CUR_CS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT TOP 8  
             ISNULL(RTRIM(ST.Company),'')  
      FROM ORDERS OH WITH (NOLOCK)  
      JOIN STORER ST WITH (NOLOCK) ON (OH.Consigneekey = ST.Storerkey)  
      WHERE OH.Loadkey = @c_Loadkey  
      OPEN CUR_CS  
     
      FETCH NEXT FROM CUR_CS INTO @c_CSCompany  
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         IF @c_CSCompanies <> ''   
         BEGIN  
            SET @c_CSCompanies = @c_CSCompanies + ', '  
         END  
  
         SET @c_CSCompanies = @c_CSCompanies + @c_CSCompany  
  
         FETCH NEXT FROM CUR_CS INTO @c_CSCompany  
      END  
      CLOSE CUR_CS  
      DEALLOCATE CUR_CS  
  
      SELECT @c_Lot02Label = ISNULL(RTRIM(Description),'')  
      FROM CODELKUP WITH (NOLOCK)  
      WHERE Code = 'Lottable02'  
      AND Listname = 'RPTCOLHDR'  
      AND Storerkey = @c_Storerkey  
  
      SELECT @c_Lot04Label = ISNULL(RTRIM(Description),'')  
      FROM CODELKUP WITH (NOLOCK)  
      WHERE Code = 'Lottable04'  
      AND Listname = 'RPTCOLHDR'  
      AND Storerkey = @c_Storerkey  
  
      IF ISNULL(RTRIM(@c_Lot02Label),'') = ''  
      BEGIN  
         SET @c_Lot02Label = 'Batch No'  
     END  
  
      IF ISNULL(RTRIM(@c_Lot04Label),'') = ''  
      BEGIN  
         SET @c_Lot04Label = 'Exp Date'  
      END  
  
      DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT LOC.LogicalLocation  
            ,LOC.LocationType  
            ,LOC.PickZone  
            ,PD.Storerkey  
            ,PD.Sku  
            ,Skudescr = ISNULL(RTRIM(SKU.Descr),'')  
            ,PD.Loc  
            ,PD.ID   
            ,Qty = SUM(PD.Qty)  
            ,Lottable02 = ISNULL(RTRIM(LA.Lottable02),'')  
            ,LA.Lottable04  
            ,PCK.Pallet  
            ,PCK.CaseCnt   
            ,CASE WHEN @n_LinkPickdetailkey = 1 THEN PD.PickDetailKey ELSE '' END  --WL02
            ,Lottable01 = ISNULL(RTRIM(LA.Lottable01),'')     --mingle01  
            ,LA.Lottable13                                    --mingle01
      FROM ORDERS       OH    WITH (NOLOCK)   
      JOIN PICKDETAIL   PD    WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)  
      JOIN LOC          LOC   WITH (NOLOCK) ON (PD.Loc = LOC.Loc)  
      JOIN SKU          SKU   WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)  
                                            AND(PD.Sku = SKU.Sku)  
      JOIN PACK         PCK   WITH (NOLOCK) ON (SKU.Packkey = PCK.Packkey)  
      JOIN LOTATTRIBUTE LA    WITH (NOLOCK) ON (PD.Lot = LA.Lot)  
      WHERE OH.Loadkey  = @c_Loadkey  
      AND   OH.Storerkey= @c_Storerkey  
      AND   OH.OrderGroup = CASE WHEN @n_FilterByOrderGroup = 1 THEN @c_OrderGroup ELSE OH.OrderGroup END --WL02  
      GROUP BY LOC.LogicalLocation  
            ,  LOC.PickZone  
            ,  LOC.LocationType  
            ,  PD.Storerkey  
            ,  PD.Sku  
            ,  ISNULL(RTRIM(SKU.Descr),'')  
            ,  PD.Loc  
            ,  PD.ID  
            ,  ISNULL(RTRIM(LA.Lottable02),'')  
            ,  LA.Lottable04  
            ,  PCK.Pallet  
            ,  PCK.CaseCnt  
            ,  CASE WHEN @n_LinkPickdetailkey = 1 THEN PD.PickDetailKey ELSE '' END  --WL02
            ,  ISNULL(RTRIM(LA.Lottable01),'')     --mingle01  
            ,  LA.Lottable13                       --mingle01
      ORDER BY LOC.LocationType  
              ,LOC.PickZone  
              ,LOC.LogicalLocation  
              ,PD.Loc  
              ,PD.Storerkey  
              ,PD.Sku  
              
      OPEN CUR_PICK  
     
      FETCH NEXT FROM CUR_PICK INTO   @c_LogicalLocation  
                                    , @c_LocationType  
                                    , @c_PickZone  
                                    , @c_Storerkey  
                                    , @c_Sku  
                                    , @c_SkuDescr  
                                    , @c_Loc  
                                    , @c_ID  
                                    , @n_Qty  
                                    , @c_Lottable02  
                                    , @dt_Lottable04  
                                    , @n_Pallet  
                                    , @n_CaseCnt      
                                    , @c_GetPickdetailkey   --WL02 
                                    , @c_Lottable01         --mingle01   
                                    , @dt_Lottable13        --mingle01             
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         SET @c_SortLocType = @c_LocationType  
  
         IF @c_LocationType NOT IN ( 'CASE', 'PICK' )  
         BEGIN  
            SET @c_SortLocType = 'BULK'  
         END  
  
         --WL01 Start  
         SET @n_TotalQty = @n_Qty  
         --WL01 End  
  
         WHILE @n_Qty > 0  
         BEGIN  
            SET @n_QtyInPLT = 0  
            SET @n_QtyInCS  = 0  
            SET @n_QtyInEA  = 0  
            SET @n_QtyRemain= 0  
            SET @c_PickType = ''  
  
            --WL02 Start  
            SET @n_TotalCases = 0  
            --WL02 End  
  
            --WL01 Start  
            --IF @n_ShowTotalCases = 1  
            --BEGIN  
            --   SELECT @n_TotalCases = @n_TotalQty / @n_CaseCnt  
            --END  
            --ELSE  
            --BEGIN  
            --   SET @n_TotalCases = 0  
            --END  
            ----WL01 End  
  
            IF @c_SortLocType = 'BULK'  
            BEGIN  
               SET @n_QtyInPLT = CASE WHEN @n_Pallet > 0 THEN @n_Qty/@n_Pallet ELSE 0 END  
               IF @n_QtyInPLT > 0   
               BEGIN  
                  SET @c_PickType = 'FP'  
                  SET @n_QtyRemain = (@n_QtyInPLT * @n_Pallet)    
                  --WL02 Start  
                  IF @n_ShowTotalCases = 1  
                  BEGIN  
                     SELECT @n_TotalCases = @n_QtyRemain / @n_CaseCnt  
                  END  
                  ELSE  
                  BEGIN  
                     SET @n_TotalCases = 0  
                  END  
                  --WL02 End  
               END  
               ELSE  
               BEGIN  
                  SET @n_QtyInCS = CASE WHEN @n_CaseCnt > 0 THEN @n_Qty/@n_CaseCnt ELSE 0 END  
                  IF @n_QtyInCS > 0  
                  BEGIN  
                     SET @c_PickType = 'PPFC'  
                     SET @n_QtyRemain = (@n_QtyInCS * @n_CaseCnt)  
  
                     --WL02 Start  
                     IF @n_ShowTotalCases = 1  
                     BEGIN  
                        SELECT @n_TotalCases = @n_QtyRemain / @n_CaseCnt  
                     END  
                     ELSE  
                     BEGIN  
                        SET @n_TotalCases = 0  
                     END  
                     --WL02 End  
                  END  
                  ELSE  
                  BEGIN  
                     SET @c_PickType = 'PPLC'  
                     SET @n_QtyInEA   = @n_Qty  
                     SET @n_QtyRemain = @n_Qty  
                     --WL02 Start  
                     SET @n_TotalCases = 0  
                     --WL02 End  
                  END  
               END  
            END  
            ELSE   
            IF @c_SortLocType = 'CASE'  
            BEGIN  
               SET @n_QtyInCS = CASE WHEN @n_CaseCnt > 0 THEN @n_Qty/@n_CaseCnt ELSE 0 END  
               IF @n_QtyInCS > 0  
               BEGIN  
                  SET @c_PickType = 'FC'  
                  SET @n_QtyRemain = (@n_QtyInCS * @n_CaseCnt)  
  
                  --WL02 Start  
                  IF @n_ShowTotalCases = 1  
                  BEGIN  
                     SELECT @n_TotalCases = @n_QtyRemain / @n_CaseCnt  
                  END  
                  ELSE  
                  BEGIN  
                     SET @n_TotalCases = 0  
                  END  
                  --WL02 End  
  
               END  
               ELSE  
               BEGIN  
                  SET @c_PickType = 'LC'  
                  SET @n_QtyInEA   = @n_Qty  
                  SET @n_QtyRemain = @n_Qty  
                  --WL02 Start  
                  SET @n_TotalCases = 0  
                  --WL02 End  
               END  
            END  
            ELSE   
            IF @c_SortLocType = 'PICK'  
            BEGIN  
               SET @c_PickType = 'PK'  
               SET @n_QtyInEA   = @n_Qty  
               SET @n_QtyRemain = @n_Qty  
               --WL02 Start  
               SET @n_TotalCases = 0  
               --WL02 End  
            END  
  
            SET @c_ConsoOrderkey = RTRIM(@c_OrderGroup) +  RTRIM(@c_PickType) + RTRIM(@c_PickZone)   
  
            INSERT INTO #TMP_PCK  
               ( Loadkey    
               , CSCompanies     
               , ConsoOrderkey  
               , OrderGroup  
               , SortLocType  
               , PickType  
               , PickZone  
               , LocationType  
               , LogicalLocation  
               , Storerkey  
               , Sku  
               , SkuDescr  
               , Loc  
               , ID  
               , Pallet  
               , CaseCnt  
               , Qty  
               , QtyInPLT  
               , QtyInCS  
               , QtyInEA    
               , Lot02Label   
               , Lot04Label                            
               , Lottable02  
               , Lottable04  
               , TotalCases      --WL01  
               , Pickdetailkey   --WL02 
               , Lottable01      --mingle01 
               , Lottable13      --mingle01 
               )  
            VALUES   
               ( @c_Loadkey    
               , @c_CSCompanies     
               , @c_ConsoOrderkey  
               , @c_OrderGroup  
               , @c_SortLocType  
               , @c_PickType  
               , @c_PickZone  
               , @c_LocationType  
               , @c_LogicalLocation  
               , @c_Storerkey  
               , @c_Sku  
               , @c_SkuDescr  
               , @c_Loc  
               , @c_ID  
               , @n_Pallet  
               , @n_CaseCnt   
               , @n_Qty  
               , @n_QtyInPLT  
               , @n_QtyInCS  
               , @n_QtyInEA    
               , @c_Lot02Label  
               , @c_Lot04Label                             
               , @c_Lottable02  
               , @dt_Lottable04  
               , @n_TotalCases         --WL01  
               , @c_GetPickdetailkey   --WL02  
               , @c_Lottable01         --mingle01 
               , @dt_Lottable13        --mingle01 
                 
               )  
            SET @n_Qty = @n_Qty - @n_QtyRemain  
         END   
           
         FETCH NEXT FROM CUR_PICK INTO   @c_LogicalLocation  
                                       , @c_LocationType  
                                       , @c_PickZone  
                                       , @c_Storerkey  
                                       , @c_Sku  
                                       , @c_SkuDescr  
                                       , @c_Loc  
                                       , @c_ID  
                                       , @n_Qty  
                                       , @c_Lottable02  
                                       , @dt_Lottable04  
                                       , @n_Pallet  
                                       , @n_CaseCnt  
                                       , @c_GetPickdetailkey   --WL02  
                                       , @c_Lottable01  
                                       , @dt_Lottable13    
      END  
      CLOSE CUR_PICK  
      DEALLOCATE CUR_PICK  
  
      FETCH NEXT FROM CUR_LOADORD INTO @c_Loadkey, @c_OrderGroup, @c_Storerkey   
   END  
   CLOSE CUR_LOADORD  
   DEALLOCATE CUR_LOADORD  
  
   IF NOT EXISTS (SELECT 1  
                  FROM #TMP_PCK  
               )  
   BEGIN  
      GOTO QUIT_SP  
   END  
     
   SET @n_NoOfReqPSlip  = 0  
  
   SELECT @n_NoOfReqPSlip = COUNT(DISTINCT TPK.Loadkey + TPK.ConsoOrderkey)  
   FROM #TMP_PCK TPK  
   WHERE NOT EXISTS ( SELECT 1  
                      FROM PICKHEADER PH WITH (NOLOCK)   
                      WHERE PH.ExternOrderKey =  TPK.Loadkey   
                      AND PH.ConsoOrderkey = TPK.ConsoOrderKey  
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
         ,TPK.OrderGroup  
         ,TPK.SortLocType  
         ,TPK.PickType  
         ,TPK.PickZone  
         ,TPK.ConsoOrderkey  
         ,PickHeaderkey = ISNULL(RTRIM(PH.PickHeaderKey),'')  
   FROM #TMP_PCK TPK  
   LEFT JOIN PICKHEADER PH WITH (NOLOCK) ON (TPK.Loadkey = PH.ExternOrderKey)  
                                         AND(TPK.ConsoOrderkey = PH.ConsoOrderKey)  
   ORDER BY TPK.Loadkey  
         ,  TPK.OrderGroup  
         ,  TPK.PickZone  
         ,  TPK.SortLocType  
         ,  TPK.PickType  
         ,  TPK.ConsoOrderkey  
         ,  ISNULL(RTRIM(PH.PickHeaderKey),'')  
  
   OPEN CUR_PSLIP  
     
   FETCH NEXT FROM CUR_PSLIP INTO @c_Loadkey  
                                 ,@c_OrderGroup  
                                 ,@c_SortLocType  
                                 ,@c_PickType  
                                 ,@c_PickZone  
                                 ,@c_ConsoOrderkey  
                                 ,@c_PickHeaderKey  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      BEGIN TRAN  
      IF @c_PickHeaderKey = ''  
      BEGIN  
         SET @c_PickHeaderKey = 'P' + @c_PickSlipNo  
  
         INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, ConsoOrderkey, PickType, Zone, TrafficCop)  
         VALUES (@c_PickHeaderKey, @c_LoadKey, @c_ConsoOrderkey, '0', 'LB', NULL)  
  
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
            , TPK.Pallet  
            , TPK.CaseCnt  
            --, PD.Qty --INC0761176  
            , TPK.Qty --INC0761176  
      FROM #TMP_PCK TPK  
      JOIN ORDERS     OH   WITH (NOLOCK) ON (TPK.Loadkey  = OH.Loadkey)  
      JOIN PICKDETAIL PD   WITH (NOLOCK) ON (OH.Orderkey  = PD.Orderkey)  
                                         AND(TPK.Storerkey= PD.Storerkey)  
                                         AND(TPK.Sku = PD.Sku)  
                                         AND(TPK.Loc = PD.Loc)  
                                         AND(TPK.ID  = PD.ID)  
                                         AND(TPK.Pickdetailkey = CASE WHEN @n_LinkPickdetailkey = 1 THEN PD.PickDetailKey ELSE TPK.Pickdetailkey END )   --WL02  
      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (PD.Lot = LA.Lot)  
                                         AND(ISNULL(RTRIM(TPK.Lottable02),'') = ISNULL(RTRIM(LA.Lottable02),''))  
                                         AND(ISNULL(RTRIM(TPK.Lottable04),'1900-01-01') = ISNULL(RTRIM(LA.Lottable04),'1900-01-01'))  
      JOIN LOC         LOC WITH (NOLOCK) ON (TPK.Loc  = LOC.Loc)  
                                         AND(TPK.LocationType = LOC.LocationType)  
                                         AND(TPK.PickZone = LOC.PickZone)  
      WHERE TPK.Loadkey = @c_Loadkey  
      AND   TPK.ConsoOrderkey = @c_ConsoOrderkey  
      ORDER BY PD.PickDetailKey  
  
      OPEN CUR_PD  
     
      FETCH NEXT FROM CUR_PD INTO @c_PickDetailkey  
                                 ,@c_Orderkey  
                                 ,@c_OrderLineNumber  
                                 ,@c_PickType  
                                 ,@n_Pallet  
                                 ,@n_CaseCnt  
                                 ,@n_Qty  
  
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
                                    ,@n_Pallet  
                                    ,@n_CaseCnt  
                                    ,@n_Qty  
      END  
      CLOSE CUR_PD  
      DEALLOCATE CUR_PD  
  
      UPDATE #TMP_PCK  
      SET PickSlipNo  = @c_PickHeaderKey  
         ,PrintedFlag = @c_PrintedFlag  
      WHERE Loadkey   = @c_Loadkey  
      AND ConsoOrderkey  = @c_ConsoOrderkey  
  
      WHILE @@TRANCOUNT > 0   
      BEGIN  
         COMMIT TRAN  
      END  
            
      FETCH NEXT FROM CUR_PSLIP INTO @c_Loadkey  
                                    ,@c_OrderGroup  
                                    ,@c_SortLocType  
                                    ,@c_PickType  
                                    ,@c_PickZone  
                                    ,@c_ConsoOrderkey  
                                    ,@c_PickHeaderKey  
  
   END  
   CLOSE CUR_PSLIP  
   DEALLOCATE CUR_PSLIP  
     
   --WL03 Start  
   IF @n_LinkPickdetailkey = 1  
   BEGIN  
      INSERT INTO #TMP_PKPAGE  
         ( PageGroup  
         , Loadkey           
         , PickSlipNo        
         , PrintedFlag       
         , CSCompanies       
         , ConsoOrderkey     
         , OrderGroup        
         , SortLocType       
         , PickType   
         , PickTypeDescr         
         , PickZone          
         , LocationType      
         , LogicalLocation   
         , Storerkey         
         , Sku               
         , SkuDescr          
         , Loc               
         , ID                
         , Pallet            
         , CaseCnt           
         , Qty               
         , QtyInPLT          
         , QtyInCS           
         , QtyInEA           
         , Lot02Label        
         , Lot04Label        
         , Lottable02        
         , Lottable04        
         , TotalCases      --WL01  
         , Pickdetailkey   --WL02  
         , Lottable01      --mingle01  
         , Lottable13      --mingle01 
         )  
      SELECT CEILING(((ROW_NUMBER() OVER (PARTITION BY PickSlipNo ORDER BY TPK.Loadkey  
                                       ,  TPK.OrderGroup  
                                       ,  TPK.PickZone  
                                       ,  TPK.SortLocType   
                                       ,  TPK.PickType  
                                       ,  TPK.PickSlipNo  
                                       ,  TPK.LogicalLocation     
                                       ,  TPK.Loc    
                                       ,  TPK.Storerkey  
                                       ,  TPK.Sku)) ) / @n_RowPerPage)     
         ,  TPK.Loadkey           
         ,  TPK.PickSlipNo        
         ,  TPK.PrintedFlag       
         ,  TPK.CSCompanies       
         ,  TPK.ConsoOrderkey     
         ,  TPK.OrderGroup        
         ,  TPK.SortLocType   
         ,  TPK.PickType             
         ,  PickType = CASE WHEN TPK.PickType = 'FP'   THEN 'Full Pallet'  
                            WHEN TPK.PickType = 'PPFC' THEN 'Loose Pallet Case'  
                            WHEN TPK.PickType = 'PPLC' THEN 'Loose Pallet PC'  
                            WHEN TPK.PickType = 'FC' THEN 'Full Case'  
                            WHEN TPK.PickType = 'LC'   THEN 'Loose Case'  
                            WHEN TPK.PickType = 'PK'   THEN 'PC'  
                            ELSE ''   
                            END         
         ,  TPK.PickZone          
         ,  TPK.LocationType      
         ,  TPK.LogicalLocation   
         ,  TPK.Storerkey         
         ,  TPK.Sku               
         ,  TPK.SkuDescr          
         ,  TPK.Loc               
         ,  ID = CASE WHEN SortLocType = 'BULK' THEN TPK.ID ELSE '' END              
         ,  TPK.Pallet            
         ,  TPK.CaseCnt           
         ,  SUM(TPK.Qty)               
         ,  SUM(TPK.QtyInPLT)          
         ,  SUM(TPK.QtyInCS)           
         ,  SUM(TPK.QtyInEA)           
         ,  TPK.Lot02Label        
         ,  TPK.Lot04Label        
         ,  TPK.Lottable02        
         ,  TPK.Lottable04      
         ,  SUM(TPK.TotalCases)      --WL01    
         ,  ''   --WL02 
         ,  TPK.Lottable01           --mingle01       
         ,  TPK.Lottable13           --mingle01 
      FROM #TMP_PCK TPK   
      GROUP BY TPK.Loadkey           
         ,  TPK.PickSlipNo        
         ,  TPK.PrintedFlag       
         ,  TPK.CSCompanies       
         ,  TPK.ConsoOrderkey     
         ,  TPK.OrderGroup        
         ,  TPK.SortLocType   
         ,  TPK.PickType             
         ,  CASE WHEN TPK.PickType = 'FP'   THEN 'Full Pallet'  
                            WHEN TPK.PickType = 'PPFC' THEN 'Loose Pallet Case'  
                            WHEN TPK.PickType = 'PPLC' THEN 'Loose Pallet PC'  
                            WHEN TPK.PickType = 'FC'   THEN 'Full Case'  
                            WHEN TPK.PickType = 'LC'   THEN 'Loose Case'  
                            WHEN TPK.PickType = 'PK'   THEN 'PC'  
                            ELSE ''   
                            END         
         ,  TPK.PickZone          
         ,  TPK.LocationType      
         ,  TPK.LogicalLocation   
         ,  TPK.Storerkey         
         ,  TPK.Sku               
         ,  TPK.SkuDescr          
         ,  TPK.Loc               
         ,  CASE WHEN SortLocType = 'BULK' THEN TPK.ID ELSE '' END              
         ,  TPK.Pallet            
         ,  TPK.CaseCnt                  
         ,  TPK.Lot02Label        
         ,  TPK.Lot04Label        
         ,  TPK.Lottable02        
         ,  TPK.Lottable04   
         ,  TPK.Lottable01      --mingle01  
         ,  TPK.Lottable13      --mingle01  
      ORDER BY TPK.Loadkey  
         ,  TPK.OrderGroup  
         ,  TPK.PickZone  
         ,  TPK.SortLocType   
         ,  TPK.PickType  
         ,  TPK.PickSlipNo  
         ,  TPK.LogicalLocation     
         ,  TPK.Loc    
         ,  TPK.Storerkey  
         ,  TPK.Sku  
   END  
   ELSE  
   BEGIN  
      INSERT INTO #TMP_PKPAGE  
         ( PageGroup  
         , Loadkey           
         , PickSlipNo        
         , PrintedFlag       
         , CSCompanies       
         , ConsoOrderkey     
         , OrderGroup        
         , SortLocType       
         , PickType   
         , PickTypeDescr         
         , PickZone          
         , LocationType      
         , LogicalLocation   
         , Storerkey         
         , Sku               
         , SkuDescr          
         , Loc               
         , ID                
         , Pallet            
         , CaseCnt           
         , Qty               
         , QtyInPLT          
         , QtyInCS           
         , QtyInEA           
         , Lot02Label        
         , Lot04Label        
         , Lottable02        
         , Lottable04        
         , TotalCases      --WL01  
         , Pickdetailkey   --WL02  
         , Lottable01      --mingle01    
         , Lottable13      --mingle01 
         )  
      SELECT CEILING(((ROW_NUMBER() OVER (PARTITION BY PickSlipNo ORDER BY TPK.Loadkey  
                                       ,  TPK.OrderGroup  
                                       ,  TPK.PickZone  
                                       ,  TPK.SortLocType   
                                       ,  TPK.PickType  
                                       ,  TPK.PickSlipNo  
                                       ,  TPK.LogicalLocation     
                            ,  TPK.Loc    
                                       ,  TPK.Storerkey  
                                       ,  TPK.Sku)) ) / @n_RowPerPage)     
         ,  TPK.Loadkey           
         ,  TPK.PickSlipNo        
         ,  TPK.PrintedFlag       
         ,  TPK.CSCompanies       
         ,  TPK.ConsoOrderkey     
         ,  TPK.OrderGroup        
         ,  TPK.SortLocType   
         ,  TPK.PickType             
         ,  PickType = CASE WHEN TPK.PickType = 'FP'   THEN 'Full Pallet'  
                            WHEN TPK.PickType = 'PPFC' THEN 'Loose Pallet Case'  
                            WHEN TPK.PickType = 'PPLC' THEN 'Loose Pallet PC'  
                            WHEN TPK.PickType = 'FC'   THEN 'Full Case'  
                            WHEN TPK.PickType = 'LC'   THEN 'Loose Case'  
                            WHEN TPK.PickType = 'PK'   THEN 'PC'  
                            ELSE ''   
                            END         
         ,  TPK.PickZone          
         ,  TPK.LocationType      
         ,  TPK.LogicalLocation   
         ,  TPK.Storerkey         
         ,  TPK.Sku               
         ,  TPK.SkuDescr          
         ,  TPK.Loc               
         ,  ID = CASE WHEN SortLocType = 'BULK' THEN TPK.ID ELSE '' END              
         ,  TPK.Pallet            
         ,  TPK.CaseCnt           
         ,  TPK.Qty               
         ,  TPK.QtyInPLT          
         ,  TPK.QtyInCS           
         ,  TPK.QtyInEA           
         ,  TPK.Lot02Label        
         ,  TPK.Lot04Label        
         ,  TPK.Lottable02        
         ,  TPK.Lottable04      
         ,  TPK.TotalCases      --WL01    
         ,  TPK.Pickdetailkey   --WL02   
         ,  TPK.Lottable01      --mingle01       
         ,  TPK.Lottable13      --mingle01  
      FROM #TMP_PCK TPK   
      ORDER BY TPK.Loadkey  
         ,  TPK.OrderGroup  
         ,  TPK.PickZone  
         ,  TPK.SortLocType   
         ,  TPK.PickType  
         ,  TPK.PickSlipNo  
         ,  TPK.LogicalLocation     
         ,  TPK.Loc    
         ,  TPK.Storerkey  
         ,  TPK.Sku  
   END  
   --WL03 End  
  
   INSERT INTO #TMP_PAGING  
      (  Loadkey     
      ,  PickSlipNo  
      ,  OrderGroup  
      ,  PickZone  
      ,  SortLocType  
      ,  PickType  
      ,  PageGroup  
      ,  PageNo  
      )  
   SELECT DISTINCT  
         TPKPG.Loadkey     
      ,  TPKPG.PickSlipNo  
      ,  TPKPG.OrderGroup  
      ,  TPKPG.PickZone  
      ,  TPKPG.SortLocType  
      ,  TPKPG.PickType  
      ,  TPKPG.PageGroup  
      ,  PageNo = DENSE_RANK() OVER (PARTITION BY   
                                      TPKPG.Loadkey  
                                    , TPKPG.OrderGroup  
                               ORDER BY   
                                      TPKPG.Loadkey  
                                    , TPKPG.OrderGroup  
                                    , TPKPG.PickZone  
                                    , TPKPG.SortLocType  
                                    , TPKPG.PickType  
                                    , TPKPG.Pickslipno  
                                    , TPKPG.PageGroup  
                                    )  
   FROM  #TMP_PKPAGE TPKPG  
  
QUIT_SP:  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_LOADORD') in (0 , 1)    
   BEGIN  
      CLOSE CUR_LOADORD  
      DEALLOCATE CUR_LOADORD  
   END  
  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_CS') in (0 , 1)    
   BEGIN  
      CLOSE CUR_CS  
      DEALLOCATE CUR_CS  
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
  
   SELECT @n_PageNo = COUNT(DISTINCT Pickslipno + CONVERT(NCHAR(5), PageGroup))  
   FROM #TMP_PKPAGE TPKPG  
        
   SELECT TPKPG.RowNo  
         ,TPKPG.PickSlipNo  
         ,TPKPG.PrintedFlag  
         ,PG.PageNo  
         ,TotalPageNo = ISNULL((  SELECT MAX(#TMP_PAGING.PageNo)  
                                 FROM #TMP_PAGING   
                                 WHERE TPKPG.Loadkey = #TMP_PAGING.Loadkey  
                                 AND   TPKPG.OrderGroup = #TMP_PAGING.OrderGroup   
                              ),0)  
         ,TPKPG.Loadkey  
         ,TPKPG.OrderGroup   
         ,TPKPG.CSCompanies    
         ,TPKPG.SortLocType   
         ,TPKPG.PickTypeDescr  
         ,TPKPG.PickZone  
         ,TPKPG.Storerkey  
         ,TPKPG.Sku  
         ,TPKPG.SkuDescr  
         ,TPKPG.LogicalLocation     
         ,TPKPG.Loc  
         ,TPKPG.ID    
         ,TPKPG.Qty  
         ,TPKPG.QtyInPLT  
         ,TPKPG.QtyInCS  
         ,TPKPG.QtyInEA   
         ,TPKPG.Lot02Label    
         ,TPKPG.Lot04Label                         
         ,TPKPG.Lottable02  
         ,TPKPG.Lottable04   
         ,TPKPG.TotalCases                      --WL01   
         ,@n_ShowTotalCases AS ShowTotalCases   --WL01   
         ,@n_ShowGrandTotal AS ShowGrandTotal   --WL01 
         ,TPKPG.Lottable01                      --mingle01  
         ,TPKPG.Lottable13                      --mingle01   
   FROM #TMP_PKPAGE TPKPG  
   LEFT JOIN #TMP_PAGING PG ON ( TPKPG.Loadkey    = PG.Loadkey )    
                            AND( TPKPG.PickSlipNo = PG.PickSlipNo )    
                            AND( TPKPG.OrderGroup = PG.OrderGroup )    
                            AND( TPKPG.PickZone   = PG.PickZone )    
                            AND( TPKPG.SortLocType= PG.SortLocType )     
                            AND( TPKPG.PickType   = PG.PickType )     
                            AND( TPKPG.PageGroup  = PG.PageGroup )    
   WHERE TPKPG.PickSlipNo <> ''   
   ORDER BY TPKPG.RowNo  
END -- procedure


GO