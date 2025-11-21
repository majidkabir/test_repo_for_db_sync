SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Stored Procedure: ispConsoPickList33_2                                  */  
/* Creation Date:                                                          */  
/* Copyright: IDS                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose:                                                                */  
/*                                                                         */  
/* Called By: r_dw_consolidate_pick33_2                                    */  
/*                                                                         */  
/* PVCS Version: 1.4                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date         Author  Ver   Purposes                                     */  
/* 29-APR-2013  YTWan   1.1   Fixed for generate 10 orders per pickslip    */
/*                            (Wan01)                                      */
/* 07-JUN-2013  YTWan   1.2   SOS#280007-MY Project Starlight-Loading Sheet*/
/*                            Sorting Sequence. To Sync Box# in loadsheet  */
/*                           (Wan02)                                       */
/* 23-Sep-2013  YTWan   1.3   SOS#289942 - LFA - Pick Slip Generation      */
/*                            Process Improvement (Wan03)                  */
/* 14-FEB-2013  YTWan   1.4   SOS#301551-PH - LFAsia Picking Slip          */
/*                            Generation Process &#65533; Cluster Pick Slip*/
/*                            and Normal Pick.(Wan04)                      */
/* 23-Apr-2014  YTWan   1.5   SOS#308966 - Amend Normal and Cluster Pick   */
/*                            Pickslip.(Wan05)                             */
/* 15-Dec-2018  TLTING  1.6   remove set ansi at the end of sp             */
/* 28-Jan-2019  TLTING_ext 1.7  enlarge externorderkey field length        */
/***************************************************************************/  
CREATE PROC [dbo].[ispConsoPickList33_2] (    
         @c_Loadkey  NVARCHAR(10) )    
AS    
BEGIN       
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
   SET ANSI_NULLS OFF            
    
   DECLARE @n_StartTCnt       INT   
         , @n_Err             INT     
         , @b_Success         INT              
         , @c_Errmsg          NVARCHAR(255)    
          
         , @c_PickHeaderKey   NVARCHAR(10)    
         , @c_PickSlipNo      NVARCHAR(10)   
         , @c_PrintedFlag     NVARCHAR(1)     
  
   DECLARE @c_Orderkey        NVARCHAR(10)  
         , @n_OrderSize       FLOAT  
         , @n_OrderWgt        FLOAT                --(Wan05)
         , @c_PickZone        NVARCHAR(30)  
         , @c_PZone           NVARCHAR(10)  
         , @c_PZType          NVARCHAR(1)  
         , @c_RptType         NVARCHAR(1)  
         , @c_Category        NVARCHAR(5)  
           
   DECLARE @n_NoOfOrder       INT  
         , @n_TotalOrderSize  FLOAT  
  
         , @n_LocationSeq     INT  
         , @c_LogicalLoc      NVARCHAR(10)  
  
   DECLARE @c_Route1          NVARCHAR(10)  
         , @c_Route2          NVARCHAR(10)  
         , @c_Route3          NVARCHAR(10)   
         , @c_Route4          NVARCHAR(10)   
         , @c_Route5          NVARCHAR(10)   
         , @c_Route6          NVARCHAR(10)   
         , @c_Route7          NVARCHAR(10)   
         , @c_Route8          NVARCHAR(10)   
         , @c_Route9          NVARCHAR(10)   
  
         , @c_Externorderkey1 NVARCHAR(50)       --tlting_ext
         , @c_Externorderkey2 NVARCHAR(50)       --tlting_ext
         , @c_Externorderkey3 NVARCHAR(50)       --tlting_ext
         , @c_Externorderkey4 NVARCHAR(50)       --tlting_ext
         , @c_Externorderkey5 NVARCHAR(50)       --tlting_ext
         , @c_Externorderkey6 NVARCHAR(50)       --tlting_ext
         , @c_Externorderkey7 NVARCHAR(50)       --tlting_ext
         , @c_Externorderkey8 NVARCHAR(50)       --tlting_ext
         , @c_Externorderkey9 NVARCHAR(50)       --tlting_ext
      
         , @n_OrderSize1      FLOAT   
         , @n_OrderSize2      FLOAT   
         , @n_OrderSize3      FLOAT   
         , @n_OrderSize4      FLOAT   
         , @n_OrderSize5      FLOAT   
         , @n_OrderSize6      FLOAT   
         , @n_OrderSize7      FLOAT   
         , @n_OrderSize8      FLOAT   
         , @n_OrderSize9      FLOAT   
       
         , @n_BoxNo1          INT      
         , @n_BoxNo2          INT       
         , @n_BoxNo3          INT       
         , @n_BoxNo4          INT       
         , @n_BoxNo5          INT         
         , @n_BoxNo6          INT       
         , @n_BoxNo7          INT       
         , @n_BoxNo8          INT                
         , @n_BoxNo9          INT  
  
         , @n_CSQty1          INT          
         , @n_CSQty2          INT       
         , @n_CSQty3          INT       
         , @n_CSQty4          INT       
         , @n_CSQty5          INT       
         , @n_CSQty6          INT       
         , @n_CSQty7          INT       
         , @n_CSQty8          INT       
         , @n_CSQty9          INT    
  
         , @n_EAQty1          INT      
         , @n_EAQty2          INT       
         , @n_EAQty3          INT       
         , @n_EAQty4          INT       
         , @n_EAQty5          INT         
         , @n_EAQty6          INT       
         , @n_EAQty7          INT       
         , @n_EAQty8          INT       
         , @n_EAQty9          INT  
  
         , @n_Qty1            INT      
         , @n_Qty2            INT       
         , @n_Qty3            INT       
         , @n_Qty4            INT       
         , @n_Qty5            INT         
         , @n_Qty6            INT       
         , @n_Qty7            INT       
         , @n_Qty8            INT       
         , @n_Qty9            INT  
       
         , @n_BoxNo           INT  
         , @n_FoundBoxNo      INT  
         , @c_PPickSlipNo     NVARCHAR(10)  
         , @c_Route           NVARCHAR(10)  
         , @c_OrderSize       FLOAT  
         , @c_ExternOrderKey  NVARCHAR(30)   
  
         , @c_Storerkey       NVARCHAR(15)  
         , @c_Loc             NVARCHAR(10)  
         , @c_Sku             NVARCHAR(20)  
         , @c_Descr           NVARCHAR(60)  
         , @c_Lottable02      NVARCHAR(18)  
         , @n_CaseCnt         INT  
         , @c_PackUOM1        NVARCHAR(10)        
         , @c_PackUOM3        NVARCHAR(10)  
         , @n_Qty             INT   
         , @n_CSQty           INT  
         , @n_EAQty           INT  
    
         , @n_TotalQty        INT   
         , @n_TotalCS         INT  
         , @n_TotalEA         INT  

         , @c_MHEType         NVARCHAR(60)
   SET @n_StartTCnt = @@TRANCOUNT     
    
   /*Create Temp Result table */   
  
   CREATE TABLE #TMP_PZ  
      (  Orderkey          NVARCHAR(10)   NOT NULL  
      ,  PickZone          NVARCHAR(10)   NOT NULL  
      )  
  
   CREATE TABLE #TMP_ORD   
      (  Orderkey          NVARCHAR(10)   NOT NULL  
      ,  OrderSize         FLOAT          NOT NULL  
      ,  OrderWgt          FLOAT          NOT NULL          --(Wan05)
      ,  PickZone          NVARCHAR(30)   NOT NULL  
      ,  PZType            NVARCHAR(1)    NOT NULL  
--      ,  RptType           NVARCHAR(1)    NOT NULL  
      ,  Category          NVARCHAR(5)    NOT NULL  
      ,  PickSlipNo        NVARCHAR(10)   NOT NULL  
      ,  PrintedFlag       NVARCHAR(1)    NOT NULL
      ,  MHEType           NVARCHAR(60)     NULL            --(Wan03)        
      )  
  
 CREATE TABLE #TMP_CONSO  
      ( SeqNo           INT   IDENTITY (1,1)  
      , PickSlipNo      NVARCHAR(10)      NULL    
      , Printedflag     NVARCHAR(1)       NULL     
      , LoadKey         NVARCHAR(10)      NULL  
      , PickZone        NVARCHAR(30)      NULL     
      , Loc             NVARCHAR(10)      NULL  
      , Storerkey       NVARCHAR(15)      NULL  
      , Sku             NVARCHAR(20)      NULL  
      , Descr           NVARCHAR(60)      NULL   
      , Lottable02      NVARCHAR(18)      NULL   
      , CaseCnt         INT               NULL   
      , PackUOM1        NVARCHAR(10)      NULL   
      , PackUOM3        NVARCHAR(10)      NULL      
      , Route1          NVARCHAR(10)      NULL  
      , Route2          NVARCHAR(10)      NULL  
      , Route3          NVARCHAR(10)      NULL  
      , Route4          NVARCHAR(10)      NULL  
      , Route5          NVARCHAR(10)      NULL  
      , Route6          NVARCHAR(10)      NULL  
      , Route7          NVARCHAR(10)      NULL  
      , Route8          NVARCHAR(10)      NULL  
      , Route9          NVARCHAR(10)      NULL  
      , ExternOrderKey1 NVARCHAR(50)      NULL       --tlting_ext
      , ExternOrderKey2 NVARCHAR(50)      NULL       --tlting_ext
      , ExternOrderKey3 NVARCHAR(50)      NULL       --tlting_ext
      , ExternOrderKey4 NVARCHAR(50)      NULL       --tlting_ext
      , ExternOrderKey5 NVARCHAR(50)      NULL       --tlting_ext
      , ExternOrderKey6 NVARCHAR(50)      NULL       --tlting_ext
      , ExternOrderKey7 NVARCHAR(50)      NULL       --tlting_ext
      , ExternOrderKey8 NVARCHAR(50)      NULL       --tlting_ext
      , ExternOrderKey9 NVARCHAR(50)      NULL       --tlting_ext
      , OrderSize1      FLOAT             NULL  
      , OrderSize2      FLOAT             NULL  
      , OrderSize3      FLOAT             NULL  
      , OrderSize4      FLOAT             NULL   
      , OrderSize5      FLOAT             NULL  
      , OrderSize6      FLOAT             NULL  
      , OrderSize7      FLOAT             NULL  
      , OrderSize8      FLOAT             NULL    
      , OrderSize9      FLOAT             NULL   
      , BoxNo1          NVARCHAR(2)       NULL  
      , BoxNo2          NVARCHAR(2)       NULL  
      , BoxNo3          NVARCHAR(2)       NULL  
      , BoxNo4          NVARCHAR(2)       NULL  
      , BoxNo5          NVARCHAR(2)       NULL  
      , BoxNo6          NVARCHAR(2)       NULL  
      , BoxNo7          NVARCHAR(2)       NULL  
      , BoxNo8          NVARCHAR(2)       NULL  
      , BoxNo9          NVARCHAR(2)       NULL  
      , TotalCS         INT               NULL  
      , CSQty1          INT               NULL     
      , CSQty2          INT               NULL  
      , CSQty3          INT               NULL  
      , CSQty4          INT               NULL  
      , CSQty5          INT               NULL  
      , CSQty6          INT               NULL  
      , CSQty7          INT               NULL  
      , CSQty8          INT               NULL  
      , CSQty9          INT               NULL  
      , TotalEA         INT               NULL  
      , EAQty1          INT               NULL  
      , EAQty2          INT               NULL  
      , EAQty3          INT               NULL  
      , EAQty4          INT               NULL  
      , EAQty5          INT               NULL  
      , EAQty6          INT               NULL  
      , EAQty7          INT               NULL  
      , EAQty8          INT               NULL  
      , EAQty9          INT               NULL  
      , TotalQty        INT               NULL  
      , Qty1            INT               NULL  
      , Qty2            INT               NULL  
      , Qty3            INT               NULL  
      , Qty4            INT               NULL  
      , Qty5            INT               NULL  
      , Qty6            INT               NULL  
      , Qty7            INT               NULL  
      , Qty8            INT               NULL  
      , Qty9            INT               NULL 
      , MHEType         NVARCHAR(60)      NULL              --(Wan03) 
  )  
        
   CREATE TABLE #TMP_SKUGRP   
      (  SeqNo          INT   IDENTITY (1,1)  
      ,  PickSlipNo     NVARCHAR(10)      NULL  
      ,  OrderKey       NVARCHAR(10)      NULL   
      ,  Loc            NVARCHAR(10)      NULL  
      ,  Storerkey      NVARCHAR(15)      NULL  
      ,  Sku            NVARCHAR(20)      NULL       
      ,  Lottable02     NVARCHAR(18)      NULL  
      ,  BoxNo          INT               NULL  
      ,  GroupNo        INT               NULL    
      )   
  
   WHILE @@TranCount > 0  
   BEGIN  
      COMMIT TRAN  
   END  
  
   BEGIN TRAN  
  
   INSERT INTO #TMP_PZ (Orderkey, PickZone)  
   SELECT   Orderkey = PD.Orderkey  
         ,  PZ       = ISNULL(RTRIM(LOC.PickZone),'')   
   FROM LOADPLANDETAIL    LPD WITH (NOLOCK)  
   JOIN PICKDETAIL        PD  WITH (NOLOCK) ON (LPD.Orderkey = PD.Orderkey)  
   JOIN LOC               LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)  
   WHERE LPD.LoadKey = @c_Loadkey  
   GROUP BY PD.Orderkey  
         ,  ISNULL(RTRIM(LOC.PickZone),'')  
  
   DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT   Orderkey = PD.Orderkey  
         ,  OrderSize= SUM(PD.Qty * SKU.StdCube)  
         ,  OrderWgt = SUM(PD.Qty * SKU.StdGrossWgt)        --(Wan05)
         ,  PZType   = CASE WHEN COUNT(DISTINCT LOC.PickZone ) <= 1 THEN 'S' ELSE 'M' END  
         --,  PZ       = MIN(ISNULL(RTRIM(LOC.PickZone),''))                                                   --(Wan05)
         ,  PZ       = MAX(CASE WHEN LOC.PickZone IN ('LA', 'LB', 'LC', 'LS') THEN '' ELSE LOC.PickZone  END)  --(Wan05)
         ,  PickSlipNo = ISNULL(RTRIM(RL.PickSlipNo),'')  
         ,  PrintedFlag= CASE WHEN ISNULL(RTRIM(RL.PickSlipNo),'') = '' THEN 'N' ELSE 'Y' END   
   FROM LOADPLANDETAIL    LPD WITH (NOLOCK)  
   JOIN PICKDETAIL        PD  WITH (NOLOCK) ON (LPD.Orderkey = PD.Orderkey)  
   JOIN SKU               SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)  
                                            AND(PD.Sku = SKU.Sku)  
   JOIN LOC               LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)  
   LEFT JOIN REFKEYLOOKUP RL  WITH (NOLOCK) ON (PD.PickdetailKey = RL.PickDetailKey)   
   LEFT JOIN PICKHEADER   PH  WITH (NOLOCK) ON (RL.PickSlipNo = PH.PickHeaderKey AND LPD.Loadkey = PH.ExternOrderkey AND PH.Zone = 'LP')   
   WHERE LPD.LoadKey = @c_Loadkey  
   GROUP BY PD.Orderkey  
         ,  ISNULL(RTRIM(RL.PickSlipNo),'') 
   HAVING   SUM(PD.Qty * SKU.StdCube) <= 0.12               -- (Wan03)  
       AND  SUM(PD.Qty * SKU.StdGrossWgt) <= 15             -- (Wan05)
  
   OPEN CUR_ORD    
  
   FETCH NEXT FROM CUR_ORD INTO  @c_OrderKey   
                              ,  @n_OrderSize 
                              ,  @n_OrderWgt                --(Wan05) 
                              ,  @c_PZType  
                              ,  @c_PickZone  
                              ,  @c_PickSlipNo   
                              ,  @c_PrintedFlag  
   WHILE @@FETCH_STATUS <> -1    
   BEGIN
      --(Wan05) - START
      SET @c_Category = CASE WHEN @c_PZType = 'S' AND @c_PickZone IN ('LC', 'LG', 'LS') THEN 'C1'    
                             WHEN @c_PickZone = '' THEN 'C2'  
                             ELSE ''
                             END
      --(Wan05) - END
  
      IF @c_PZType = 'M'  
      BEGIN  
         SET @c_PickZone = ''  
  
         DECLARE CUR_PZ CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PickZone  
         FROM #TMP_PZ  
         WHERE Orderkey = @c_Orderkey  
  
         OPEN CUR_PZ    
  
         FETCH NEXT FROM CUR_PZ INTO @c_PZone   
         WHILE @@FETCH_STATUS <> -1    
         BEGIN  
            SET @c_PickZone = @c_PickZone + @c_PZone + ', '  
            FETCH NEXT FROM CUR_PZ INTO @c_PZone   
         END  
         CLOSE CUR_PZ  
         DEALLOCATE CUR_PZ  
  
         IF LEN(@c_PickZone) > 0  
         BEGIN  
            SET @c_PickZone = SUBSTRING(@c_PickZone,1,LEN(@c_PickZone)-1)  
         END  
      END  
  
      --(Wan03) - START
      --SET @c_Category = CASE WHEN @c_PZType = 'S' AND @c_PickZone = 'LC' AND @n_OrderSize < 0.03 THEN 'C1' 
      --                       ELSE 'C2'  
      --                       WHEN @c_PZType = 'S' AND @c_PickZone = 'LC' AND @n_OrderSize >= 0.03 AND @n_OrderSize < 0.09 THEN 'C2'  
      --                       WHEN @c_PZType = 'S' AND @c_PickZone NOT IN ('LC', 'LF', 'LG') AND @n_OrderSize < 0.09  THEN 'C3'  
      --                       WHEN @c_PZType = 'M' AND (CHARINDEX('LD', @c_PickZone, 1) > 0 OR CHARINDEX('LE', @c_PickZone, 1) > 0 )   
      --                                         AND @n_OrderSize < 0.09 THEN 'C4'  
      --                       WHEN @c_PZType = 'M' AND(CHARINDEX('LD', @c_PickZone, 1) = 0 AND CHARINDEX('LE', @c_PickZone, 1) = 0 )  
      --                                         AND @n_OrderSize < 0.09 THEN 'C5'  
      --                       ELSE ''  
      --                       END  

      --(Wan05) - START
      --SET @c_Category = CASE WHEN (CHARINDEX('LD', @c_PickZone, 1) > 0  
      --                        OR   CHARINDEX('LE', @c_PickZone, 1) > 0 
      --                        OR   CHARINDEX('LF', @c_PickZone, 1) > 0
      --                        OR   CHARINDEX('LG', @c_PickZone, 1) > 0)  THEN ''
      --                       WHEN @c_PZType = 'S' AND @c_PickZone = 'LC' THEN 'C1'    
      --                       WHEN (CHARINDEX('LA', @c_PickZone, 1) > 0  
      --                        OR   CHARINDEX('LB', @c_PickZone, 1) > 0 
      --                        OR   CHARINDEX('LC', @c_PickZone, 1) > 0  
      --                        OR   CHARINDEX('LS', @c_PickZone, 1) > 0)                 
      --                       THEN 'C2'  
      --                       ELSE ''
      --                       END
      --(Wan05) - END
      --(Wan03) - END
  
      INSERT INTO #TMP_ORD   
            (  Orderkey       
            ,  OrderSize 
            ,  OrderWgt                                        --(Wan05)     
            ,  PZType    
            ,  PickZone      
            ,  Category   
            ,  PickSlipNo  
            ,  PrintedFlag  
            )  
      VALUES(  @c_OrderKey  
            ,  @n_OrderSize  
            ,  @n_OrderWgt                                     --(Wan05)  
            ,  @c_PZType   
            ,  @c_PickZone  
            ,  @c_Category  
            ,  @c_PickSlipNo   
            ,  @c_PrintedFlag  
            )  
      FETCH NEXT FROM CUR_ORD INTO  @c_OrderKey   
                                 ,  @n_OrderSize 
                                 ,  @n_OrderWgt                --(Wan05)  
                                 ,  @c_PZType  
                                 ,  @c_PickZone  
                                 ,  @c_PickSlipNo   
                                 ,  @c_PrintedFlag  
   END  
   CLOSE CUR_ORD  
   DEALLOCATE CUR_ORD 
 
   -- CREATE PickSlipNo for each category  START  
   DECLARE CUR_CAT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Category  
   FROM #TMP_ORD   
   WHERE Category <> ''  
   ORDER BY Category  
  
   OPEN CUR_CAT    
  
   FETCH NEXT FROM CUR_CAT INTO @c_Category  
  
   WHILE @@FETCH_STATUS <> -1    
   BEGIN  
  
      SET @n_NoOfOrder = 0  
      SET @n_TotalOrderSize = 0.00  
      SET @c_PickSlipNo = ''  
  
      DECLARE CUR_CONSO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT   DISTINCT   
               TMP.Orderkey  
            ,  TMP.OrderSize  
            ,  ISNULL(RTRIM(RL.PickSlipNo),'')  
      FROM #TMP_ORD TMP  
      JOIN LOADPLANDETAIL    LPD WITH (NOLOCK) ON (TMP.Orderkey = LPD.Orderkey)  
      JOIN PICKDETAIL        PD  WITH (NOLOCK) ON (LPD.Orderkey = PD.Orderkey)  
      LEFT JOIN REFKEYLOOKUP RL  WITH (NOLOCK) ON (PD.PickdetailKey = RL.PickDetailKey)   
      LEFT JOIN PICKHEADER   PH  WITH (NOLOCK) ON (RL.PickSlipNo = PH.PickHeaderKey AND LPD.Loadkey = PH.ExternOrderkey AND PH.Zone = 'LP')  
      WHERE TMP.Category = @c_Category  
      ORDER BY ISNULL(RTRIM(RL.PickSlipNo),'')  
            ,  TMP.Orderkey                
  
      OPEN CUR_CONSO    
  
      FETCH NEXT FROM CUR_CONSO INTO @c_Orderkey  
                                    ,@n_OrderSize  
                                    ,@c_PickHeaderKey  
      WHILE @@FETCH_STATUS <> -1    
      BEGIN  
         IF @c_PickHeaderKey <> ''  
         BEGIN  
            SET @c_PrintedFlag = 'Y'  
            GOTO NEXT_REC  
         END 
         --(Wan01) Fixed for generate 10 orders per pickslip (START) 
--         ELSE  
--         BEGIN  
  
--            SET @c_PrintedFlag = 'N'  
--            SET @n_NoOfOrder = @n_NoOfOrder + 1  
--            SET @n_TotalOrderSize = @n_TotalOrderSize + @n_OrderSize  
--  
--            IF @n_NoOfOrder > 9 OR @n_TotalOrderSize > 0.27  
--            BEGIN  
--               SET @c_PickSlipNo = ''  
--               SET @n_NoOfOrder = 0  
--               SET @n_TotalOrderSize = 0  
--            END  
--         END 
         --(Wan01) Fixed for generate 10 orders per pickslip (START) 
  
         IF @c_PickSlipNo = ''   
         BEGIN  
            SET @b_success = 0  
            EXECUTE nspg_GetKey    
                  'PICKSLIP'  
               ,  9       
               ,  @c_PickSlipNo   OUTPUT     
               ,  @b_success      OUTPUT     
               ,  @n_err          OUTPUT     
               ,  @c_errmsg       OUTPUT    
  
            IF @b_success = 1     
            BEGIN    
               SET @c_PickSlipNo = 'P' + @c_PickSlipNo              
               INSERT INTO PICKHEADER  
                     (  PickHeaderKey  
                     ,  ExternOrderkey  
                     ,  Zone  
                     ,  PickType  
                     ,  Wavekey  
                     )    
               VALUES   
                     (  @c_PickSlipNo  
                     ,  @c_Loadkey  
                     ,  'LP'  
                     ,  '0'  
                     ,  @c_PickSlipNo  
                     )   
            END  
            --INSERT PICKHEADER  
         END  
  
  
         INSERT INTO REFKEYLOOKUP   
               (  PickDetailkey  
               ,  Orderkey  
               ,  OrderLineNumber  
               ,  Loadkey  
               ,  PickSlipNo  
               )   
         SELECT   PickDetailKey  
               ,  Orderkey  
               ,  OrderLineNumber  
               ,  @c_Loadkey  
               ,  @c_PickSlipNo   
         FROM PICKDETAIL WITH (NOLOCK)  
         WHERE Orderkey = @c_Orderkey  
         AND NOT EXISTS (SELECT 1 FROM REFKEYLOOKUP WITH (NOLOCK)   
                         WHERE PickDetailKey = PICKDETAIL.PickDetailKey)  
  
         SET @c_PrintedFlag = 'N'                                    --(Wan01) 

         UPDATE #TMP_ORD  
            SET PickSlipNo = @c_PickSlipNo--@c_PickHeaderKey  
               ,PrintedFlag= @c_PrintedFlag  
         WHERE Orderkey = @c_Orderkey  
  
         --(Wan01) Fixed for generate 10 orders per pickslip (START) 
         SET @n_NoOfOrder = @n_NoOfOrder + 1  
         SET @n_TotalOrderSize = @n_TotalOrderSize + @n_OrderSize  

         IF @n_NoOfOrder >= 9 OR @n_TotalOrderSize >= 0.36 --0.27    --(Wan03)
         BEGIN  
            SET @c_PickSlipNo = ''  
            SET @n_NoOfOrder = 0  
            SET @n_TotalOrderSize = 0  
         END  
         --(Wan01) Fixed for generate 10 orders per pickslip (END) 
         NEXT_REC:  
         FETCH NEXT FROM CUR_CONSO INTO @c_Orderkey  
                                       ,@n_OrderSize  
                                       ,@c_PickHeaderKey  
      END  
      CLOSE CUR_CONSO  
      DEALLOCATE CUR_CONSO  
  
      FETCH NEXT FROM CUR_CAT INTO @c_Category  
   END  
   CLOSE CUR_CAT  
   DEALLOCATE CUR_CAT  
   -- CREATE PickSlipNo for each category  END  

   IF EXISTS(SELECT 1 FROM PICKHEADER (NOLOCK)     
             WHERE ExternOrderKey = @c_Loadkey    
             AND   Zone = 'LP' AND PickType = '0')    
   BEGIN  
      UPDATE PICKHEADER WITH (ROWLOCK)  
      SET   PickType = '1'     
         ,  TrafficCop = NULL  
      FROM #TMP_ORD TMP  
      JOIN PICKHEADER ON (TMP.PickSlipNo = PICKHEADER.PickHeaderKey) AND (PICKHEADER.Zone = 'LP') AND (PICKHEADER.PickType = '0')    
      WHERE TMP.PrintedFlag = 'Y'  
   END  
  
   SET @n_BoxNo   = 0   
   SET @c_PPickSlipNo= ''
  
   --CREATE Consolidate data base on Report layout --START  
   DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT   DISTINCT  
            TMP.PickSlipNo  
        ,   TMP.Orderkey  
        ,   TMP.PrintedFlag  
        ,   ISNULL(RTRIM(LOC.PickZone),'')  
        ,   LocationSeq = CASE ISNULL(RTRIM(LOC.LocationType),'') WHEN 'OTHER' THEN 3  
                                                                  WHEN 'CASE'  THEN 2  
                                                                  WHEN 'PICK'  THEN 1  
                                                                  END  
        ,   ISNULL(RTRIM(LOC.LogicalLocation),'')  
        ,   ISNULL(RTRIM(PD.Loc),'')  
        ,   ISNULL(RTRIM(PD.Storerkey),'')  
        ,   ISNULL(RTRIM(PD.Sku),'')     
        ,   ISNULL(RTRIM(LA.Lottable02),'')  
   FROM #TMP_ORD TMP  
   JOIN LOADPLANDETAIL LPD  WITH (NOLOCK) ON (TMP.Orderkey = LPD.Orderkey)   
   JOIN PICKDETAIL     PD   WITH (NOLOCK) ON (LPD.OrderKey = PD.Orderkey)  
   JOIN LOTATTRIBUTE   LA   WITH (NOLOCK) ON (PD.Lot = LA.Lot)  
   JOIN LOC            LOC  WITH (NOLOCK) ON (PD.LOC = LOC.LOC)  
   JOIN REFKEYLOOKUP   RL   WITH (NOLOCK) ON (PD.PickDetailkey = RL.PickDetailKey)  
                                          AND(TMP.PickSlipNo = RL.PickSlipNo)  
   JOIN PICKHEADER     PH   WITH (NOLOCK) ON (RL.PickSlipNo = PH.PickHeaderKey)  
                                          AND(LPD.LoadKey = PH.ExternOrderkey)  
                                          AND(PH.Zone = 'LP')  
  
   WHERE Category <> ''   
   ORDER BY TMP.PickSlipNo  
--        ,   TMP.Orderkey  
        ,   ISNULL(RTRIM(LOC.PickZone),'')  
        ,   CASE ISNULL(RTRIM(LOC.LocationType),'') WHEN 'OTHER' THEN 3  
                                                    WHEN 'CASE'  THEN 2  
                                                    WHEN 'PICK'  THEN 1  
                                                    END   
        ,   ISNULL(RTRIM(LOC.LogicalLocation),'')  
        ,   ISNULL(RTRIM(PD.Storerkey),'')  
        ,   ISNULL(RTRIM(PD.Sku),'')     
        ,   ISNULL(RTRIM(LA.Lottable02),'')
        ,   TMP.Orderkey                                                                           --(Wan02)
  
   OPEN CUR_ORD  
   
   FETCH NEXT FROM CUR_ORD INTO  @c_PickSlipNo  
                              ,  @c_Orderkey  
                              ,  @c_PrintedFlag  
                              ,  @c_PZone  
                              ,  @n_LocationSeq  
                              ,  @c_LogicalLoc   
                              ,  @c_Loc  
                              ,  @c_Storerkey    
                              ,  @c_Sku  
                              ,  @c_Lottable02   
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      IF @c_PickSlipNo <> @c_PPickSlipNo   
      BEGIN   
         SET @n_BoxNo = 0  
         SET @c_PickZone = ''  
      END   
  
      IF CHARINDEX(@c_PZone, @c_PickZone, 1) = 0 AND LEN(@c_PZone) > 0  
      BEGIN   
         SET @c_PickZone = @c_PickZone + @c_PZone + ', '  
      END  
  
      IF NOT EXISTS (SELECT 1    
                     FROM   #TMP_SKUGRP    
                     WHERE  PickSlipNo = @c_PickSlipNo   
                     AND    OrderKey   = @c_OrderKey)  
      BEGIN              
         SET @n_BoxNo = @n_BoxNo + 1
         
         INSERT INTO #TMP_SKUGRP    
               (  PickSlipNo  
               ,  Orderkey  
               ,  Loc  
               ,  Storerkey  
               ,  Sku  
               ,  Lottable02  
               ,  BoxNo  
               )   
         VALUES  
               (  @c_PickSlipNo  
               ,  @c_Orderkey  
               ,  @c_Loc  
               ,  @c_Storerkey  
               ,  @c_Sku  
               ,  @c_Lottable02  
               ,  @n_BoxNo  
               )   
      END -- IF ORDERKEY NOT EXIST    
      ELSE    
      BEGIN    
         IF NOT EXISTS (  SELECT 1   
                          FROM #TMP_SKUGRP   
                          WHERE PickSlipNo= @c_PickSlipNo    
                          AND Orderkey    = @c_Orderkey  
                          AND Loc         = @c_Loc  
                          AND Storerkey   = @c_Storerkey  
                          AND Sku         = @c_Sku   
                          AND Lottable02  = @c_lottable02 )    
         BEGIN    
            SELECT @n_FoundBoxNo= BoxNo    
            FROM #TMP_SKUGRP    
            WHERE  PickSlipNo = @c_PickSlipNo   
            AND    OrderKey   = @c_OrderKey     
      
            INSERT INTO #TMP_SKUGRP    
                  (  PickSlipNo  
                  ,  Orderkey  
                  ,  Loc  
                  ,  Storerkey  
                  ,  Sku  
                  ,  Lottable02  
                  ,  BoxNo  
                  )   
            VALUES  
                  (  @c_PickSlipNo  
                  ,  @c_Orderkey  
                  ,  @c_Loc  
                  ,  @c_Storerkey  
                  ,  @c_Sku  
                  ,  @c_Lottable02  
                  ,  @n_FoundBoxNo  
                  )   
  
         END    
      END    
      SET @c_PPickSlipNo = @c_PickSlipNo  
      FETCH NEXT FROM CUR_ORD INTO  @c_PickSlipNo  
                                 ,  @c_Orderkey  
                                 ,  @c_PrintedFlag  
                                 ,  @c_PZone  
                                 ,  @n_LocationSeq  
                                 ,  @c_LogicalLoc   
                                 ,  @c_Loc  
                                 ,  @c_Storerkey    
                                 ,  @c_Sku  
                                 ,  @c_Lottable02   
  
      IF @c_PPickSlipNo <> @c_PickSlipNo OR @@FETCH_STATUS = -1   
      BEGIN  
         IF LEN(@c_PickZone) > 0   
         BEGIN  
            SET @c_PickZone = SUBSTRING(@c_PickZone,1,LEN(@c_PickZone) - 1)   
         END  
  
         --(Wan03) - START
         SET @c_MHEType = ''
         SELECT @c_MHEType = CASE WHEN COUNT(DISTINCT Orderkey) <= 3 AND SUM(OrderSize) <= 0.12 THEN 'Small Trolley' 
                                  ELSE 'Cluster Trolley' END
         FROM #TMP_ORD 
         WHERE PickSlipNo = @c_PPickSlipNo 
         --(Wan03) - END

         UPDATE #TMP_ORD   
            SET PickZone = @c_PickZone  
               ,MHEType  = @c_MHEType                       --(Wan03)
         WHERE PickSlipNo = @c_PPickSlipNo  
      END  
   END -- WHILE FETCH STATUS <> -1    
   CLOSE CUR_ORD    
   DEALLOCATE CUR_ORD    
    
   DECLARE CUR_SKUGRP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT   #TMP_SKUGRP.PickSlipNo  
         ,  #TMP_SKUGRP.Loc  
         ,  #TMP_SKUGRP.Storerkey  
         ,  #TMP_SKUGRP.Sku  
         ,  #TMP_SKUGRP.Lottable02    
         ,  ISNULL(RTRIM(SKU.Descr),'')   
         ,  ISNULL(PACK.CaseCnt,0)  
         ,  ISNULL(RTRIM(PACK.PackUOM1),'')  
         ,  ISNULL(RTRIM(PACK.PackUOM3),'')     
   FROM  #TMP_SKUGRP   
   JOIN SKU   WITH (NOLOCK) ON (#TMP_SKUGRP.Storerkey = SKU.Storerkey) AND (#TMP_SKUGRP.Sku = SKU.Sku)  
   JOIN PACK  WITH (NOLOCK) ON (SKU.Packkey = PACK.PAckkey)  
   GROUP BY #TMP_SKUGRP.PickSlipNo  
         ,  #TMP_SKUGRP.Loc  
         ,  #TMP_SKUGRP.Storerkey  
         ,  #TMP_SKUGRP.Sku  
         ,  #TMP_SKUGRP.Lottable02    
         ,  ISNULL(RTRIM(SKU.Descr),'')   
         ,  ISNULL(PACK.CaseCnt,0)  
         ,  ISNULL(RTRIM(PACK.PackUOM1),'')  
         ,  ISNULL(RTRIM(PACK.PackUOM3),'')     
   ORDER BY MIN(#TMP_SKUGRP.SeqNo)  
   OPEN CUR_SKUGRP    
  
  
   FETCH NEXT FROM CUR_SKUGRP INTO  @c_PickSlipNo  
                                 ,  @c_Loc  
                                 ,  @c_Storerkey    
                                 ,  @c_Sku  
                                 ,  @c_Lottable02    
                                 ,  @c_Descr  
                                 ,  @n_CaseCnt  
                                 ,  @c_PackUOM1  
                                 ,  @c_PackUOM3  
   WHILE @@FETCH_STATUS <> -1    
   BEGIN   
  
      SET @n_EAQty1 = 0 SET @n_EAQty2 = 0 SET @n_EAQty3 = 0 SET @n_EAQty4 = 0 SET @n_EAQty5 = 0  
      SET @n_EAQty6 = 0 SET @n_EAQty7 = 0 SET @n_EAQty8 = 0 SET @n_EAQty9 = 0  
  
      SET @n_CSQty1 = 0 SET @n_CSQty2 = 0 SET @n_CSQty3 = 0 SET @n_CSQty4 = 0 SET @n_CSQty5 = 0  
      SET @n_CSQty6 = 0 SET @n_CSQty7 = 0 SET @n_CSQty8 = 0 SET @n_CSQty9 = 0  
  
      SET @n_Qty1 = 0   SET @n_Qty2 = 0   SET @n_Qty3 = 0   SET @n_Qty4 = 0   SET @n_Qty5 = 0  
      SET @n_Qty6 = 0   SET @n_Qty7 = 0   SET @n_Qty8 = 0   SET @n_Qty9 = 0  
  
      SET @c_Route1 = '' SET @c_Route2 = '' SET @c_Route3 = '' SET @c_Route4 = '' SET @c_Route5 = ''  
      SET @c_Route6 = '' SET @c_Route7 = '' SET @c_Route8 = '' SET @c_Route9 = ''  
  
      SET @c_Externorderkey1 = '' SET @c_Externorderkey2 = ''  SET @c_Externorderkey3 = '' SET @c_Externorderkey4 = ''  
      SET @c_Externorderkey5 = '' SET @c_Externorderkey6 = ''  SET @c_Externorderkey7 = '' SET @c_Externorderkey8 = ''  
      SET @c_Externorderkey9 = ''  
  
      SET @n_OrderSize1 = 0 SET @n_OrderSize2 = 0 SET @n_OrderSize3 = 0 SET @n_OrderSize4 = 0 SET @n_OrderSize5 = 0  
      SET @n_OrderSize6 = 0 SET @n_OrderSize7 = 0 SET @n_OrderSize8 = 0 SET @n_OrderSize9 = 0  
  
      SET @n_BoxNo1 = 0 SET @n_BoxNo2 = 0 SET @n_BoxNo3 = 0 SET @n_BoxNo4 = 0 SET @n_BoxNo5 = 0  
      SET @n_BoxNo6 = 0 SET @n_BoxNo7 = 0 SET @n_BoxNo8 = 0 SET @n_BoxNo9 = 0  
  
      SET @n_TotalQty = 0  SET @n_TotalCS = 0 SET @n_TotalEA = 0  
  
      DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
      SELECT OrderKey  
            ,BoxNo    
      FROM   #TMP_SKUGRP    
      WHERE  PickSlipNo = @c_PickSlipNo  
      AND    Loc        = @c_Loc  
      AND    Storerkey  = @c_Storerkey   
      AND    Sku        = @c_Sku  
      AND    Lottable02 = @c_Lottable02   
      ORDER BY BoxNo  
        
      OPEN CUR_ORD    
      FETCH NEXT FROM CUR_ORD INTO  @c_OrderKey  
                                 ,  @n_BoxNo    
  
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         SET @n_Qty = 0  
         SET @n_CSQty = 0    
  
         SELECT @n_Qty = SUM(PD.QTY)    
         FROM REFKEYLOOKUP   RL WITH (NOLOCK)    
         JOIN PICKDETAIL   PD WITH (NOLOCK) ON (RL.Pickdetailkey = PD.PickDetailKey)   
         JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (PD.Lot = LA.Lot)  
         WHERE RL.PickSlipNo = @c_PickSlipNo  
         AND   RL.OrderKey   = @c_OrderKey   
         AND   RL.Loadkey    = @c_Loadkey   
         AND   PD.SKU        = @c_SKU    
         AND   PD.LOC        = @c_LOC    
         AND   LA.Lottable02 = @c_Lottable02  
  
         SET @n_CSQty = CASE WHEN @n_CaseCnt > 0 THEN FLOOR(@n_Qty / @n_CaseCnt) ELSE 0 END   
  
         SET @n_EAQty = CASE WHEN @n_CaseCnt > 0 THEN @n_Qty % @n_CaseCnt ELSE @n_Qty END  
  
         SET @n_TotalQty = @n_TotalQty + @n_Qty  
  
         SELECT   @c_Route         = ISNULL(RTRIM(Route),'')  
               ,  @c_Externorderkey= LTRIM(CASE WHEN LEFT(Externorderkey,5) = Storerkey THEN STUFF(ISNULL(RTRIM(Externorderkey),''),1,5,'')   
                                                                                        ELSE ISNULL(RTRIM(Externorderkey),'')  
                                                                                        END)  
         FROM ORDERS WITH (NOLOCK)  
         WHERE Orderkey = @c_Orderkey  
  
         SELECT   @n_OrderSize = ISNULL(OrderSize,0.00)  
               ,  @c_PickZone  = ISNULL(RTRIM(PickZone),'')  
               ,  @c_MHEType   = ISNULL(RTRIM(MHEType),'')
         FROM #TMP_ORD  
         WHERE PickSlipNo = @c_PickSlipNo  
         AND   Orderkey   = @c_Orderkey  
  
         SET @n_CSQty1 = CASE WHEN @n_BoxNo = 1 THEN @n_CSQty ELSE @n_CSQty1 END  
         SET @n_CSQty2 = CASE WHEN @n_BoxNo = 2 THEN @n_CSQty ELSE @n_CSQty2 END  
         SET @n_CSQty3 = CASE WHEN @n_BoxNo = 3 THEN @n_CSQty ELSE @n_CSQty3 END  
         SET @n_CSQty4 = CASE WHEN @n_BoxNo = 4 THEN @n_CSQty ELSE @n_CSQty4 END  
         SET @n_CSQty5 = CASE WHEN @n_BoxNo = 5 THEN @n_CSQty ELSE @n_CSQty5 END  
         SET @n_CSQty6 = CASE WHEN @n_BoxNo = 6 THEN @n_CSQty ELSE @n_CSQty6 END  
         SET @n_CSQty7 = CASE WHEN @n_BoxNo = 7 THEN @n_CSQty ELSE @n_CSQty7 END  
         SET @n_CSQty8 = CASE WHEN @n_BoxNo = 8 THEN @n_CSQty ELSE @n_CSQty8 END  
         SET @n_CSQty9 = CASE WHEN @n_BoxNo = 9 THEN @n_CSQty ELSE @n_CSQty9 END  
  
         SET @n_EAQty1 = CASE WHEN @n_BoxNo = 1 THEN @n_EAQty ELSE @n_EAQty1 END  
         SET @n_EAQty2 = CASE WHEN @n_BoxNo = 2 THEN @n_EAQty ELSE @n_EAQty2 END  
         SET @n_EAQty3 = CASE WHEN @n_BoxNo = 3 THEN @n_EAQty ELSE @n_EAQty3 END  
         SET @n_EAQty4 = CASE WHEN @n_BoxNo = 4 THEN @n_EAQty ELSE @n_EAQty4 END  
         SET @n_EAQty5 = CASE WHEN @n_BoxNo = 5 THEN @n_EAQty ELSE @n_EAQty5 END  
         SET @n_EAQty6 = CASE WHEN @n_BoxNo = 6 THEN @n_EAQty ELSE @n_EAQty6 END  
         SET @n_EAQty7 = CASE WHEN @n_BoxNo = 7 THEN @n_EAQty ELSE @n_EAQty7 END  
         SET @n_EAQty8 = CASE WHEN @n_BoxNo = 8 THEN @n_EAQty ELSE @n_EAQty8 END  
         SET @n_EAQty9 = CASE WHEN @n_BoxNo = 9 THEN @n_EAQty ELSE @n_EAQty9 END  
  
         SET @n_Qty1 = CASE WHEN @n_BoxNo = 1 THEN @n_Qty ELSE @n_Qty1 END  
         SET @n_Qty2 = CASE WHEN @n_BoxNo = 2 THEN @n_Qty ELSE @n_Qty2 END  
         SET @n_Qty3 = CASE WHEN @n_BoxNo = 3 THEN @n_Qty ELSE @n_Qty3 END  
         SET @n_Qty4 = CASE WHEN @n_BoxNo = 4 THEN @n_Qty ELSE @n_Qty4 END  
         SET @n_Qty5 = CASE WHEN @n_BoxNo = 5 THEN @n_Qty ELSE @n_Qty5 END  
         SET @n_Qty6 = CASE WHEN @n_BoxNo = 6 THEN @n_Qty ELSE @n_Qty6 END  
         SET @n_Qty7 = CASE WHEN @n_BoxNo = 7 THEN @n_Qty ELSE @n_Qty7 END  
         SET @n_Qty8 = CASE WHEN @n_BoxNo = 8 THEN @n_Qty ELSE @n_Qty8 END  
         SET @n_Qty9 = CASE WHEN @n_BoxNo = 9 THEN @n_Qty ELSE @n_Qty9 END  
  
         SET @c_Route1 = CASE WHEN @n_BoxNo = 1 THEN @c_Route ELSE @c_Route1 END  
         SET @c_Route2 = CASE WHEN @n_BoxNo = 2 THEN @c_Route ELSE @c_Route2 END  
         SET @c_Route3 = CASE WHEN @n_BoxNo = 3 THEN @c_Route ELSE @c_Route3 END  
         SET @c_Route4 = CASE WHEN @n_BoxNo = 4 THEN @c_Route ELSE @c_Route4 END  
         SET @c_Route5 = CASE WHEN @n_BoxNo = 5 THEN @c_Route ELSE @c_Route5 END  
         SET @c_Route6 = CASE WHEN @n_BoxNo = 6 THEN @c_Route ELSE @c_Route6 END  
         SET @c_Route7 = CASE WHEN @n_BoxNo = 7 THEN @c_Route ELSE @c_Route7 END  
         SET @c_Route8 = CASE WHEN @n_BoxNo = 8 THEN @c_Route ELSE @c_Route8 END  
         SET @c_Route9 = CASE WHEN @n_BoxNo = 9 THEN @c_Route ELSE @c_Route9 END  
  
         SET @c_Externorderkey1 = CASE WHEN @n_BoxNo = 1 THEN @c_Externorderkey ELSE @c_Externorderkey1 END  
         SET @c_Externorderkey2 = CASE WHEN @n_BoxNo = 2 THEN @c_Externorderkey ELSE @c_Externorderkey2 END  
         SET @c_Externorderkey3 = CASE WHEN @n_BoxNo = 3 THEN @c_Externorderkey ELSE @c_Externorderkey3 END  
         SET @c_Externorderkey4 = CASE WHEN @n_BoxNo = 4 THEN @c_Externorderkey ELSE @c_Externorderkey4 END  
         SET @c_Externorderkey5 = CASE WHEN @n_BoxNo = 5 THEN @c_Externorderkey ELSE @c_Externorderkey5 END  
         SET @c_Externorderkey6 = CASE WHEN @n_BoxNo = 6 THEN @c_Externorderkey ELSE @c_Externorderkey6 END  
         SET @c_Externorderkey7 = CASE WHEN @n_BoxNo = 7 THEN @c_Externorderkey ELSE @c_Externorderkey7 END  
         SET @c_Externorderkey8 = CASE WHEN @n_BoxNo = 8 THEN @c_Externorderkey ELSE @c_Externorderkey8 END  
         SET @c_Externorderkey9 = CASE WHEN @n_BoxNo = 9 THEN @c_Externorderkey ELSE @c_Externorderkey9 END  
  
         SET @n_OrderSize1 = CASE WHEN @n_BoxNo = 1 THEN @n_OrderSize ELSE @n_OrderSize1 END  
         SET @n_OrderSize2 = CASE WHEN @n_BoxNo = 2 THEN @n_OrderSize ELSE @n_OrderSize2 END  
         SET @n_OrderSize3 = CASE WHEN @n_BoxNo = 3 THEN @n_OrderSize ELSE @n_OrderSize3 END  
         SET @n_OrderSize4 = CASE WHEN @n_BoxNo = 4 THEN @n_OrderSize ELSE @n_OrderSize4 END  
         SET @n_OrderSize5 = CASE WHEN @n_BoxNo = 5 THEN @n_OrderSize ELSE @n_OrderSize5 END  
         SET @n_OrderSize6 = CASE WHEN @n_BoxNo = 6 THEN @n_OrderSize ELSE @n_OrderSize6 END  
         SET @n_OrderSize7 = CASE WHEN @n_BoxNo = 7 THEN @n_OrderSize ELSE @n_OrderSize7 END  
         SET @n_OrderSize8 = CASE WHEN @n_BoxNo = 8 THEN @n_OrderSize ELSE @n_OrderSize8 END  
         SET @n_OrderSize9 = CASE WHEN @n_BoxNo = 9 THEN @n_OrderSize ELSE @n_OrderSize9 END  
  
         SET @n_BoxNo1 = CASE WHEN @n_BoxNo = 1 THEN @n_BoxNo ELSE @n_BoxNo1 END  
         SET @n_BoxNo2 = CASE WHEN @n_BoxNo = 2 THEN @n_BoxNo ELSE @n_BoxNo2 END  
         SET @n_BoxNo3 = CASE WHEN @n_BoxNo = 3 THEN @n_BoxNo ELSE @n_BoxNo3 END  
         SET @n_BoxNo4 = CASE WHEN @n_BoxNo = 4 THEN @n_BoxNo ELSE @n_BoxNo4 END  
         SET @n_BoxNo5 = CASE WHEN @n_BoxNo = 5 THEN @n_BoxNo ELSE @n_BoxNo5 END  
         SET @n_BoxNo6 = CASE WHEN @n_BoxNo = 6 THEN @n_BoxNo ELSE @n_BoxNo6 END  
         SET @n_BoxNo7 = CASE WHEN @n_BoxNo = 7 THEN @n_BoxNo ELSE @n_BoxNo7 END  
         SET @n_BoxNo8 = CASE WHEN @n_BoxNo = 8 THEN @n_BoxNo ELSE @n_BoxNo8 END  
         SET @n_BoxNo9 = CASE WHEN @n_BoxNo = 9 THEN @n_BoxNo ELSE @n_BoxNo9 END  
  
         FETCH NEXT FROM CUR_ORD INTO  @c_OrderKey  
                                     , @n_BoxNo    
    
      END    
      CLOSE CUR_ORD    
      DEALLOCATE CUR_ORD    
  
      SET @n_TotalCS = CASE WHEN @n_CaseCnt > 0 THEN FLOOR(@n_TotalQty / @n_CaseCnt) ELSE 0 END   
      SET @n_TotalEA = CASE WHEN @n_CaseCnt > 0 THEN @n_TotalQty % @n_CaseCnt ELSE @n_TotalQty END     
      INSERT INTO #TMP_CONSO   
         ( PickSlipNo       
         , Printedflag       
         , LoadKey      
         , PickZone            
         , Loc        
         , Storerkey     
         , Sku         
         , Descr        
         , Lottable02          
         , CaseCnt       
         , PACKUOM1      
         , PACKUOM3      
         , Route1        
         , Route2        
         , Route3        
         , Route4        
         , Route5        
         , Route6        
         , Route7        
         , Route8        
         , Route9        
         , ExternOrderKey1   
         , ExternOrderKey2   
         , ExternOrderKey3   
         , ExternOrderKey4   
         , ExternOrderKey5   
         , ExternOrderKey6   
         , ExternOrderKey7   
         , ExternOrderKey8   
         , ExternOrderKey9   
         , OrderSize1      
         , OrderSize2      
         , OrderSize3      
         , OrderSize4      
         , OrderSize5        
         , OrderSize6      
         , OrderSize7      
         , OrderSize8      
         , OrderSize9      
         , BoxNo1          
         , BoxNo2          
         , BoxNo3            
         , BoxNo4            
         , BoxNo5           
         , BoxNo6            
         , BoxNo7            
         , BoxNo8            
         , BoxNo9   
         , TotalCS  
         , CSQty1          
         , CSQty2            
         , CSQty3            
         , CSQty4            
         , CSQty5            
         , CSQty6            
         , CSQty7            
         , CSQty8            
         , CSQty9  
         , TotalEA            
         , EAQty1            
         , EAQty2            
         , EAQty3            
         , EAQty4            
         , EAQty5            
         , EAQty6            
         , EAQty7            
         , EAQty8            
         , EAQty9  
         , TotalQty            
         , Qty1               
         , Qty2               
         , Qty3               
         , Qty4               
         , Qty5               
         , Qty6               
         , Qty7               
         , Qty8     
         , Qty9
         , MHEType                  --(Wan03)            
         )  
      VALUES   
         (  @c_PickSlipNo  
         ,  @c_Printedflag      
         ,  @c_Loadkey   
         ,  @c_PickZone    
         ,  @c_Loc  
         ,  @c_Storerkey     
         ,  @c_Sku   
         ,  @c_Descr  
         ,  @c_Lottable02  
         ,  @n_CaseCnt    
         ,  @c_PackUOM1    
         ,  @c_PackUOM3    
  
         ,  @c_Route1  
         ,  @c_Route2  
         ,  @c_Route3  
         ,  @c_Route4  
         ,  @c_Route5  
         ,  @c_Route6  
         ,  @c_Route7  
         ,  @c_Route8  
         ,  @c_Route9  
  
         ,  @c_ExternOrderkey1  
         ,  @c_ExternOrderkey2  
         ,  @c_ExternOrderkey3  
         ,  @c_ExternOrderkey4  
         ,  @c_ExternOrderkey5  
         ,  @c_ExternOrderkey6  
         ,  @c_ExternOrderkey7  
         ,  @c_ExternOrderkey8  
         ,  @c_ExternOrderkey9  
  
         ,  CASE WHEN @n_BoxNo1 > 0 THEN @n_OrderSize1 ELSE NULL END  
         ,  CASE WHEN @n_BoxNo2 > 0 THEN @n_OrderSize2 ELSE NULL END  
         ,  CASE WHEN @n_BoxNo3 > 0 THEN @n_OrderSize3 ELSE NULL END  
         ,  CASE WHEN @n_BoxNo4 > 0 THEN @n_OrderSize4 ELSE NULL END  
         ,  CASE WHEN @n_BoxNo5 > 0 THEN @n_OrderSize5 ELSE NULL END  
         ,  CASE WHEN @n_BoxNo6 > 0 THEN @n_OrderSize6 ELSE NULL END  
         ,  CASE WHEN @n_BoxNo7 > 0 THEN @n_OrderSize7 ELSE NULL END  
         ,  CASE WHEN @n_BoxNo8 > 0 THEN @n_OrderSize8 ELSE NULL END  
         ,  CASE WHEN @n_BoxNo9 > 0 THEN @n_OrderSize9 ELSE NULL END  
  
         ,  CASE WHEN @n_BoxNo1 > 0 THEN RIGHT('0' + CONVERT(VARCHAR(2), @n_BoxNo1), 2) ELSE '' END  
         ,  CASE WHEN @n_BoxNo2 > 0 THEN RIGHT('0' + CONVERT(VARCHAR(2), @n_BoxNo2), 2) ELSE '' END  
         ,  CASE WHEN @n_BoxNo3 > 0 THEN RIGHT('0' + CONVERT(VARCHAR(2), @n_BoxNo3), 2) ELSE '' END  
         ,  CASE WHEN @n_BoxNo4 > 0 THEN RIGHT('0' + CONVERT(VARCHAR(2), @n_BoxNo4), 2) ELSE '' END  
         ,  CASE WHEN @n_BoxNo5 > 0 THEN RIGHT('0' + CONVERT(VARCHAR(2), @n_BoxNo5), 2) ELSE '' END  
         ,  CASE WHEN @n_BoxNo6 > 0 THEN RIGHT('0' + CONVERT(VARCHAR(2), @n_BoxNo6), 2) ELSE '' END  
         ,  CASE WHEN @n_BoxNo7 > 0 THEN RIGHT('0' + CONVERT(VARCHAR(2), @n_BoxNo7), 2) ELSE '' END  
         ,  CASE WHEN @n_BoxNo8 > 0 THEN RIGHT('0' + CONVERT(VARCHAR(2), @n_BoxNo8), 2) ELSE '' END  
         ,  CASE WHEN @n_BoxNo9 > 0 THEN RIGHT('0' + CONVERT(VARCHAR(2), @n_BoxNo9), 2) ELSE '' END  
  
         ,  @n_TotalCS  
         ,  @n_CSQty1  
         ,  @n_CSQty2  
         ,  @n_CSQty3  
         ,  @n_CSQty4  
         ,  @n_CSQty5  
         ,  @n_CSQty6  
         ,  @n_CSQty7  
         ,  @n_CSQty8  
         ,  @n_CSQty9  
  
         ,  @n_TotalEA  
         ,  @n_EAQty1  
         ,  @n_EAQty2  
         ,  @n_EAQty3  
         ,  @n_EAQty4  
         ,  @n_EAQty5  
         ,  @n_EAQty6  
         ,  @n_EAQty7  
         ,  @n_EAQty8  
         ,  @n_EAQty9  
  
         ,  @n_TotalQty  
         ,  @n_Qty1               
         ,  @n_Qty2               
         ,  @n_Qty3               
         ,  @n_Qty4               
         ,  @n_Qty5               
         ,  @n_Qty6               
         ,  @n_Qty7               
         ,  @n_Qty8  
         ,  @n_Qty9 
         ,  @c_MHEType              --(Wan03)  
         )           
        
      FETCH NEXT FROM CUR_SKUGRP INTO  @c_PickSlipNo  
                                    ,  @c_Loc  
                                    ,  @c_Storerkey    
                                    ,  @c_Sku  
                                    ,  @c_Lottable02    
                                    ,  @c_Descr  
                                    ,  @n_CaseCnt  
                                    ,  @c_PackUOM1  
                                    ,  @c_PackUOM3   
   END    
   CLOSE CUR_SKUGRP    
   DEALLOCATE CUR_SKUGRP    
     
  
     
  
   UPDATE #TMP_CONSO  
   SET      Route1            = MAX_Route1            
         ,  Route2            = MAX_Route2            
         ,  Route3            = MAX_Route3            
         ,  Route4            = MAX_Route4            
         ,  Route5            = MAX_Route5            
         ,  Route6            = MAX_Route6            
         ,  Route7            = MAX_Route7            
         ,  Route8            = MAX_Route8            
         ,  Route9            = MAX_Route9            
         ,  ExternOrderKey1   = MAX_ExternOrderKey1   
         ,  ExternOrderKey2   = MAX_ExternOrderKey2   
         ,  ExternOrderKey3   = MAX_ExternOrderKey3   
         ,  ExternOrderKey4   = MAX_ExternOrderKey4   
         ,  ExternOrderKey5   = MAX_ExternOrderKey5   
         ,  ExternOrderKey6   = MAX_ExternOrderKey6   
         ,  ExternOrderKey7   = MAX_ExternOrderKey7   
         ,  ExternOrderKey8   = MAX_ExternOrderKey8   
         ,  ExternOrderKey9   = MAX_ExternOrderKey9   
         ,  OrderSize1        = MAX_OrderSize1        
         ,  OrderSize2        = MAX_OrderSize2        
         ,  OrderSize3        = MAX_OrderSize3        
         ,  OrderSize4        = MAX_OrderSize4        
         ,  OrderSize5        = MAX_OrderSize5        
         ,  OrderSize6        = MAX_OrderSize6        
         ,  OrderSize7        = MAX_OrderSize7        
         ,  OrderSize8        = MAX_OrderSize8        
         ,  OrderSize9        = MAX_OrderSize9        
         ,  BoxNo1            = MAX_BoxNo1            
         ,  BoxNo2            = MAX_BoxNo2            
         ,  BoxNo3            = MAX_BoxNo3            
         ,  BoxNo4            = MAX_BoxNo4            
         ,  BoxNo5            = MAX_BoxNo5            
         ,  BoxNo6            = MAX_BoxNo6            
         ,  BoxNo7            = MAX_BoxNo7            
         ,  BoxNo8            = MAX_BoxNo8            
         ,  BoxNo9            = MAX_BoxNo9            
   FROM #TMP_CONSO TMP  
     JOIN (SELECT PickSlipNo                                                                       
               ,  MAX_Route1          = MAX(Route1)                                               
               ,  MAX_Route2           = MAX(Route2)                                               
               ,  MAX_Route3           = MAX(Route3)                                               
               ,  MAX_Route4           = MAX(Route4)                                               
               ,  MAX_Route5           = MAX(Route5)                                               
               ,  MAX_Route6           = MAX(Route6)                                               
               ,  MAX_Route7           = MAX(Route7)                                               
               ,  MAX_Route8           = MAX(Route8)                                               
               ,  MAX_Route9           = MAX(Route9)                                               
               ,  MAX_ExternOrderKey1  = MAX(ExternOrderKey1)                                      
               ,  MAX_ExternOrderKey2  = MAX(ExternOrderKey2)                                      
               ,  MAX_ExternOrderKey3  = MAX(ExternOrderKey3)                                      
               ,  MAX_ExternOrderKey4  = MAX(ExternOrderKey4)                                      
               ,  MAX_ExternOrderKey5  = MAX(ExternOrderKey5)                                      
               ,  MAX_ExternOrderKey6  = MAX(ExternOrderKey6)                                      
               ,  MAX_ExternOrderKey7  = MAX(ExternOrderKey7)                                      
               ,  MAX_ExternOrderKey8  = MAX(ExternOrderKey8)                                      
               ,  MAX_ExternOrderKey9  = MAX(ExternOrderKey9)                                      
               ,  MAX_OrderSize1       = MAX(OrderSize1)                                           
               ,  MAX_OrderSize2       = MAX(OrderSize2)                                           
               ,  MAX_OrderSize3       = MAX(OrderSize3)                                           
               ,  MAX_OrderSize4       = MAX(OrderSize4)                                           
               ,  MAX_OrderSize5       = MAX(OrderSize5)                                           
               ,  MAX_OrderSize6       = MAX(OrderSize6)                                           
               ,  MAX_OrderSize7       = MAX(OrderSize7)                                           
               ,  MAX_OrderSize8       = MAX(OrderSize8)                                           
               ,  MAX_OrderSize9       = MAX(OrderSize9)                                           
               ,  MAX_BoxNo1           = MAX(BoxNo1)                                               
               ,  MAX_BoxNo2           = MAX(BoxNo2)                                               
               ,  MAX_BoxNo3           = MAX(BoxNo3)                                               
               ,  MAX_BoxNo4           = MAX(BoxNo4)                                               
               ,  MAX_BoxNo5           = MAX(BoxNo5)                                               
               ,  MAX_BoxNo6           = MAX(BoxNo6)                                               
               ,  MAX_BoxNo7           = MAX(BoxNo7)                                               
               ,  MAX_BoxNo8           = MAX(BoxNo8)                                               
               ,  MAX_BoxNo9           = MAX(BoxNo9)                                               
            FROM #TMP_CONSO GROUP BY PickSlipNo) TMP_MAX ON (TMP.PickSlipNo = TMP_MAX.PickSlipNo)  
   --CREATE Consolidate data base on Report layout --END  
  
   SELECT  PickSlipNo       
         , Printedflag       
         , LoadKey      
         , PickZone            
         , Loc        
         , Storerkey     
         , Sku         
         , Descr        
         , Lottable02          
         , CaseCnt       
         , PACKUOM1      
         , PACKUOM3      
         , Route1        
         , Route2        
         , Route3        
         , Route4        
         , Route5        
         , Route6        
         , Route7        
         , Route8        
         , Route9        
         , ExternOrderKey1   
         , ExternOrderKey2   
         , ExternOrderKey3   
         , ExternOrderKey4   
         , ExternOrderKey5   
         , ExternOrderKey6   
         , ExternOrderKey7   
         , ExternOrderKey8   
         , ExternOrderKey9   
         , OrderSize1      
         , OrderSize2      
         , OrderSize3      
         , OrderSize4      
         , OrderSize5        
         , OrderSize6      
         , OrderSize7      
         , OrderSize8      
         , OrderSize9      
         , BoxNo1          
         , BoxNo2          
         , BoxNo3            
         , BoxNo4            
         , BoxNo5           
         , BoxNo6            
         , BoxNo7            
         , BoxNo8            
         , BoxNo9   
         , TotalCS  
         , CSQty1          
         , CSQty2            
         , CSQty3            
         , CSQty4            
         , CSQty5            
         , CSQty6            
         , CSQty7            
         , CSQty8            
         , CSQty9  
         , TotalEA            
         , EAQty1            
         , EAQty2            
         , EAQty3            
         , EAQty4            
         , EAQty5            
         , EAQty6            
         , EAQty7            
         , EAQty8            
         , EAQty9  
         , TotalQty            
         , Qty1               
         , Qty2               
         , Qty3               
         , Qty4               
         , Qty5               
         , Qty6               
         , Qty7               
         , Qty8     
         , Qty9  
         , MHEType                  --(Wan03) 
   FROM #TMP_CONSO  
   ORDER BY SeqNo
   --ORDER BY Pickslipno, loc, sku
  
   DROP TABLE #TMP_PZ  
   DROP TABLE #TMP_ORD  
   DROP TABLE #TMP_CONSO    
   DROP TABLE #TMP_SKUGRP    
  
   WHILE @@TRANCOUNT > 0     
      COMMIT TRAN    
     
   WHILE @@TRANCOUNT < @n_StartTCnt     
      BEGIN TRAN    
      
END /* main procedure */    

GO