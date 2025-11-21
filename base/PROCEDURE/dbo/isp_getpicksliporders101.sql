SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Proc: isp_GetPickSlipOrders101                                */    
/* Creation Date: 21-OCT-2019                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: CSCHONG                                                  */    
/*                                                                      */    
/* Purpose: WMS - 10845 - ID - New RCM Report for Consolidation Pick    */    
/*        :                                                             */    
/* Called By:r_dw_print_pickorder101                                    */    
/*          :                                                           */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver Purposes                                  */ 
/* 08-MAR-2022  CSCHONG   Devops Scripts Combine                        */
/* 08-MAR-2022  CSCHONG   fix infinite loop (CS01)                      */   
/************************************************************************/    
CREATE PROC [dbo].[isp_GetPickSlipOrders101]
            @c_Sourcekey   NVARCHAR(10)    
           --,@c_Sourcetype  NVARCHAR(10) = ''    
           ,@b_debug       NVARCHAR(1) = '0'    
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
    
         , @c_ConsoOrderkey   NVARCHAR(200)    
         , @c_CSCompany       NVARCHAR(45)    
         , @c_CSCompanies     NVARCHAR(400)    
         , @c_ExtOrderkey     NVARCHAR(50)    
         , @c_LoadExtOrderkey NVARCHAR(4000)    
         , @c_consigneekey    NVARCHAR(45)    
         , @c_CCompany        NVARCHAR(45)    
         , @c_City            NVARCHAR(45)    
         , @n_maxwgt          INT    
         , @n_maxcube         INT    
         , @n_Stdgrosswgt     FLOAT    
         , @n_TTLgrosswgt     FLOAT    
         , @n_stdcube         FLOAT    
         , @n_TTLStdcube      FLOAT    
         , @n_CtnPickslip     INT    
        
     
    
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
         , @n_innerpack       FLOAT  
         , @n_QtyInInner      INT  
    
         , @c_PrintedFlag     CHAR(1)    
    
         , @c_PickDetailKey NVARCHAR(10)    
         , @c_OrderLineNumber NVARCHAR(5)    
    
         , @n_PageNo          INT    
         , @n_PageGroup       INT    
         , @n_RowPerPage      FLOAT    
    
         , @n_ShowTotalCases     INT = 0            
         , @n_ShowGrandTotal     INT = 0            
         , @c_GetStorerkey       NVARCHAR(20)       
         , @n_TotalCases         INT = 0            
         , @n_TotalQty           INT = 0            
         , @c_GetPickdetailkey   NVARCHAR(10) = ''      
         , @n_LinkPickdetailkey  INT = 0                
         , @n_FilterByOrderGroup INT = 0       
         , @n_currec             INT = 1      --CS01
         , @n_maxrec             INT = 50     --CS01
       
DECLARE @c_Sourcetype  NVARCHAR(10) = ''                
    
   SET @n_StartTCnt= @@TRANCOUNT    
   SET @n_Continue = 1    
   SET @b_Success  = 1    
   SET @n_Err      = 0    
   SET @c_Errmsg   = ''    
   SET @n_RowPerPage = 20.00    
   SET @n_CtnPickslip = 1    
    
   WHILE @@TRANCOUNT > 0     
   BEGIN    
      COMMIT TRAN    
   END     
    
      CREATE TABLE #TMP_PCK    
      ( Loadkey         NVARCHAR(10)   NOT NULL    
      , PickSlipNo      NVARCHAR(10)   NOT NULL DEFAULT('')    
      , PrintedFlag     CHAR(1)        NOT NULL DEFAULT('N')    
      , LoadExtOrderkey NVARCHAR(4000) NOT NULL DEFAULT('')    
      , ConsoOrderkey   NVARCHAR(30)   NOT NULL    
      , consigneekey    NVARCHAR(45)   NOT NULL    
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
      , TotalCases      INT            NULL          
      , Pickdetailkey   NVARCHAR(10)   NULL     
      , CCompany        NVARCHAR(45)   NULL      
      , CCity           NVARCHAR(45)   NULL   
      , InnerPack       FLOAT          NOT NULL DEFAULT(0.00)  
      , QtyInInner      INT            NOT NULL DEFAULT(0)        
      )    
    
   CREATE TABLE #TMP_PKPAGE    
      ( RowNo           INT IDENTITY(1,1)  NOT NULL         PRIMARY KEY       
      , PageGroup       INT            NOT NULL DEFAULT(0)    
      --, PageNo          INT            NOT NULL DEFAULT(0)    
      , Loadkey         NVARCHAR(10)   NOT NULL    
      , PickSlipNo      NVARCHAR(10)   NOT NULL DEFAULT('')    
      , PrintedFlag     CHAR(1)        NOT NULL DEFAULT('N')    
      , LoadExtOrderkey NVARCHAR(400)  NOT NULL DEFAULT('')    
      , ConsoOrderkey   NVARCHAR(30)   NOT NULL    
      , consigneekey    NVARCHAR(45)   NOT NULL    
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
      , Lot04Label      NVARCHAR(20)   NOT NULL DEFAULT('')      
      , Lottable02      NVARCHAR(18)   NOT NULL DEFAULT(0)       
      , Lottable04      DATETIME       NULL    
      , TotalCases      INT            NULL          
      , Pickdetailkey   NVARCHAR(10)   NULL     
      , CCompany        NVARCHAR(45)   NULL     
      , CCity           NVARCHAR(45)   NULL  
      , InnerPack       FLOAT          NOT NULL DEFAULT(0.00)  
      , QtyInInner      INT            NOT NULL DEFAULT(0)               
      )    
    
 CREATE TABLE #TMP_PAGING    
      ( RowNo           INT IDENTITY(1,1)  NOT NULL         PRIMARY KEY       
      , PageGroup       INT            NOT NULL DEFAULT(0)    
      , PageNo          INT            NOT NULL DEFAULT(0)    
      , Loadkey         NVARCHAR(10)   NOT NULL    
      , PickSlipNo      NVARCHAR(10)   NOT NULL DEFAULT('')    
      , consigneekey    NVARCHAR(45)   NOT NULL    
      , SortLocType     NVARCHAR(10)   NOT NULL DEFAULT('')    
      , PickType        NVARCHAR(10)   NOT NULL    
      , PickZone        NVARCHAR(10)   NOT NULL    
      )    
    
   IF @c_Sourcetype = 'WP'    
   BEGIN    
            
      SELECT @c_GetStorerkey = OH.Storerkey    
      FROM ORDERS     OH WITH (NOLOCK)    
      JOIN WAVEDETAIL WD WITH (NOLOCK) ON (OH.Orderkey = WD.Orderkey)    
      WHERE WD.Wavekey = @c_Sourcekey    
            
    
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
    
      SELECT @c_GetStorerkey = OH.Storerkey    
      FROM ORDERS     OH WITH (NOLOCK)    
      WHERE OH.Loadkey = @c_Sourcekey    
    
   SET @n_maxwgt = 0    
   SET @n_maxcube = 0    
    
   SELECT @n_maxwgt = CASE WHEN C.code = 'stdgrosswgt' THEN CAST(C.short as INT) ELSE 0 END    
   FROM CODELKUP C WITH (NOLOCK)    
   WHERE C.LISTNAME = 'PickConfig'    
   AND C.Storerkey = @c_GetStorerkey    
   AND C.code = 'stdgrosswgt'     
    
   SELECT @n_maxcube = CASE WHEN C.code = 'stdcube' THEN CAST(C.short as INT) ELSE 0 END    
   FROM CODELKUP C WITH (NOLOCK)    
   WHERE C.LISTNAME = 'PickConfig'    
   AND C.Storerkey = @c_GetStorerkey    
   and C.code = 'stdcube'    
    
    
      DECLARE CUR_LOADORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT DISTINCT     
             Loadkey    
            ,consigneekey    
            ,Storerkey    
      FROM ORDERS WITH (NOLOCK)    
      WHERE Loadkey = @c_Sourcekey    
      ORDER BY consigneekey desc    
   END    
    
   --SELECT @n_ShowTotalCases    = ISNULL(MAX(CASE WHEN Code = 'ShowTotalCases' THEN 1 ELSE 0 END),0)      
   --      ,@n_ShowGrandTotal    = ISNULL(MAX(CASE WHEN Code = 'ShowGrandTotal' THEN 1 ELSE 0 END),0)      
   --      ,@n_LinkPickdetailkey = ISNULL(MAX(CASE WHEN Code = 'LinkPickdetailkey' THEN 1 ELSE 0 END),0)         
   --      ,@n_FilterByOrderGroup = ISNULL(MAX(CASE WHEN Code = 'FilterByOrderGroup' THEN 1 ELSE 0 END),0)       
   --FROM CODELKUP WITH (NOLOCK)      
   --WHERE ListName = 'REPORTCFG'      
   --AND   Storerkey= @c_GetStorerkey      
   --AND   Long = 'r_dw_print_pickorder101'      
   --AND   ISNULL(Short,'') <> 'N'      
    
   OPEN CUR_LOADORD    
       
FETCH NEXT FROM CUR_LOADORD INTO @c_Loadkey,@c_consigneekey, @c_Storerkey    
    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      SET @c_CSCompanies = ''    
      SET @c_LoadExtOrderkey = ''    
    
      DECLARE CUR_CS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT DISTINCT TOP 20    
             ISNULL(RTRIM(OH.Externorderkey),'')    
      FROM ORDERS OH WITH (NOLOCK)    
      --JOIN STORER ST WITH (NOLOCK) ON (OH.Consigneekey = ST.Storerkey)    
      WHERE OH.Loadkey = @c_Loadkey    
      AND OH.Consigneekey = @c_consigneekey    
      OPEN CUR_CS    
       
      FETCH NEXT FROM CUR_CS INTO @c_extorderkey    
    
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         IF @c_LoadExtOrderkey <> ''     
         BEGIN    
            SET @c_LoadExtOrderkey = @c_LoadExtOrderkey + ', '    
         END    
    
         SET @c_LoadExtOrderkey = @c_LoadExtOrderkey + @c_extorderkey    
    
         FETCH NEXT FROM CUR_CS INTO @c_extorderkey    
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
    
   SET @n_TTLgrosswgt = 0.00    
   SET @n_TTLStdcube = 0.00    
    
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
            --,CASE WHEN @n_LinkPickdetailkey = 1 THEN PD.PickDetailKey ELSE '' END       
            ,PCK.InnerPack  
            ,PD.PickDetailKey    
            ,OH.c_Company     
            ,ISNULL(OH.C_City,'')    
            ,SKU.stdgrosswgt     
            ,SKU.stdcube    
      FROM ORDERS       OH    WITH (NOLOCK)     
      JOIN PICKDETAIL   PD    WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)    
      JOIN LOC          LOC   WITH (NOLOCK) ON (PD.Loc = LOC.Loc)    
      JOIN SKU          SKU   WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)    
                                            AND(PD.Sku = SKU.Sku)    
      JOIN PACK         PCK   WITH (NOLOCK) ON (SKU.Packkey = PCK.Packkey)    
      JOIN LOTATTRIBUTE LA    WITH (NOLOCK) ON (PD.Lot = LA.Lot)    
      WHERE OH.Loadkey  = @c_Loadkey    
      AND   OH.Storerkey= @c_Storerkey    
      AND OH.Consigneekey = @c_consigneekey    
      --AND   OH.OrderGroup = CASE WHEN @n_FilterByOrderGroup = 1 THEN @c_OrderGroup ELSE OH.OrderGroup END      
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
            ,  PCK.InnerPack    
            ,  OH.c_company    
            ,  ISNULL(OH.C_City,'')    
            ,  PD.PickDetailKey    
            ,  SKU.stdgrosswgt     
            ,  SKU.stdcube    
          --  ,  CASE WHEN @n_LinkPickdetailkey = 1 THEN PD.PickDetailKey ELSE '' END       
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
                                    , @n_InnerPack  
                                    , @c_GetPickdetailkey  
                                    , @c_CCompany     
                                    , @c_City      
                                    , @n_stdgrosswgt    
                                    , @n_stdcube                            
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         SET @c_SortLocType = @c_LocationType    

         SET @n_currec = 1      --CS01
    
         IF @c_LocationType NOT IN ( 'CASE', 'PICK' )    
         BEGIN    
            SET @c_SortLocType = 'BULK'    
         END    
    
         SET @n_TotalQty = @n_Qty    
         SET @n_TTLgrosswgt = @n_TTLgrosswgt + @n_stdgrosswgt    
         SET @n_TTLStdcube = @n_TTLStdcube + @n_stdcube    
    
         IF @n_TTLgrosswgt > @n_maxwgt OR @n_TTLStdcube > @n_maxcube    
         BEGIN    
           SET @n_CtnPickslip = @n_CtnPickslip + 1    
           SET @n_TTLgrosswgt = 0.00    
           SET @n_TTLStdcube = 0.00    
         END    
    
    
         WHILE @n_Qty > 0   AND (@n_currec<@n_maxrec)   --CS01  
         BEGIN    
            SET @n_QtyInPLT = 0    
            SET @n_QtyInCS  = 0    
            SET @n_QtyInEA  = 0    
            SET @n_QtyRemain= 0    
            SET @c_PickType = ''    
            SET @n_QtyInInner = 0  
    
            SET @n_TotalCases = 0    
    
            IF @c_SortLocType = 'BULK'    
            BEGIN    
               SET @n_QtyInPLT = CASE WHEN @n_Pallet > 0 THEN @n_Qty/@n_Pallet ELSE 0 END    
               IF @n_QtyInPLT > 0     
               BEGIN    
                  SET @c_PickType = 'FP'    
                  SET @n_QtyRemain = (@n_QtyInPLT * @n_Pallet)    
    
                  IF @n_ShowTotalCases = 1    
                  BEGIN    
                     SELECT @n_TotalCases = @n_QtyRemain / @n_CaseCnt    
                  END    
                  ELSE    
                  BEGIN    
                     SET @n_TotalCases = 0    
                  END    
                 
               END    
               ELSE    
               BEGIN    
                  SET @n_QtyInCS = CASE WHEN @n_CaseCnt > 0 THEN @n_Qty/@n_CaseCnt ELSE 0 END    
                  IF @n_QtyInCS > 0    
                  BEGIN    
                     SET @c_PickType = 'PPFC'    
                     SET @n_QtyRemain = (@n_QtyInCS * @n_CaseCnt)    
    
                          
                     IF @n_ShowTotalCases = 1    
                     BEGIN    
                        SELECT @n_TotalCases = @n_QtyRemain / @n_CaseCnt    
                     END    
                     ELSE    
                     BEGIN    
                        SET @n_TotalCases = 0    
                     END    
                           
                  END    
                  ELSE    
                  BEGIN   
                    SET @n_QtyInInner = CASE WHEN @n_innerpack > 0 THEN @n_Qty/@n_innerpack ELSE 0 END     
                    IF @n_QtyInInner > 0  
                     BEGIN  
                        SET @c_PickType = 'PPLC'    
                        SET @n_QtyRemain = (@n_QtyInInner*@n_innerpack)  
                        SET @n_QtyInEA   = @n_QtyRemain    
                        SET @n_TotalCases = 0    
                     END       
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
    
                      
                  IF @n_ShowTotalCases = 1    
                  BEGIN    
                     SELECT @n_TotalCases = @n_QtyRemain / @n_CaseCnt    
                  END    
                  ELSE    
                  BEGIN    
                     SET @n_TotalCases = 0    
                  END    
               END    
               ELSE    
               BEGIN    
                  SET @c_PickType = 'LC'    
                    
                  SET @n_QtyInInner = CASE WHEN @n_innerpack > 0 THEN @n_Qty/@n_innerpack ELSE 0 END  
                  SET @n_QtyInEA   = CASE WHEN @n_QtyInInner > 0 THEN 0 ELSE @n_Qty END   
                  SET @n_QtyRemain = @n_Qty    
                        
                  SET @n_TotalCases = 0    
                        
               END    
            END    
            ELSE     
            IF @c_SortLocType = 'PICK'    
            BEGIN    
               SET @c_PickType = 'PK'    
               SET @n_QtyInEA   = @n_Qty    
               SET @n_QtyRemain = @n_Qty    
                     
               SET @n_TotalCases = 0    
                     
            END    
    
            SET @c_ConsoOrderkey = RTRIM(@c_consigneekey) +  RTRIM(@c_PickType) + RTRIM(@c_PickZone) + CAST(@n_CtnPickslip as nvarchar(5))    
    
            INSERT INTO #TMP_PCK    
               ( Loadkey      
               , LoadExtOrderkey       
               , ConsoOrderkey    
               , consigneekey    
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
               , TotalCases           
               , Pickdetailkey      
               , CCompany      
               , CCity   
               , InnerPack  
               , QtyInInner   
               )    
            VALUES     
               ( @c_Loadkey      
               , @c_LoadExtOrderkey       
               , @c_ConsoOrderkey    
               , @c_consigneekey    
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
               , @n_TotalCases              
               , @c_GetPickdetailkey     
               , @c_CCompany       
               , @c_City    
               , @n_innerpack  
               , @n_QtyInInner             
               )    
            SET @n_Qty = @n_Qty - @n_QtyRemain    
            SET @n_currec = @n_currec + 1     --CS01 S


            IF (@n_currec>@n_maxrec)
            BEGIN
               BREAK;
            END         --CS01 E
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
                                       , @n_InnerPack   
                                       , @c_GetPickdetailkey     
                                       , @c_CCompany      
                                       , @c_City      
                                       , @n_stdgrosswgt    
                                       , @n_stdcube          
      END     
      CLOSE CUR_PICK    
      DEALLOCATE CUR_PICK    
    
   FETCH NEXT FROM CUR_LOADORD INTO @c_Loadkey, @c_consigneekey, @c_Storerkey     
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
      IF @b_debug='1'    
      BEGIN    
       SELECT '#TMP_PCK',* FROM #TMP_PCK     
      END    
   DECLARE CUR_PSLIP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT    
          TPK.Loadkey    
         ,TPK.consigneekey    
         ,TPK.SortLocType    
         ,TPK.PickType    
         ,TPK.PickZone    
         ,TPK.ConsoOrderkey    
         ,PickHeaderkey = ISNULL(RTRIM(PH.PickHeaderKey),'')    
   FROM #TMP_PCK TPK    
   LEFT JOIN PICKHEADER PH WITH (NOLOCK) ON (TPK.Loadkey = PH.ExternOrderKey)    
                                         AND(TPK.ConsoOrderkey = PH.ConsoOrderKey)    
   ORDER BY TPK.Loadkey    
         ,  TPK.consigneekey    
         ,  TPK.PickZone    
         ,  TPK.SortLocType    
         ,  TPK.PickType    
         ,  TPK.ConsoOrderkey    
         ,  ISNULL(RTRIM(PH.PickHeaderKey),'')    
    
   OPEN CUR_PSLIP    
       
   FETCH NEXT FROM CUR_PSLIP INTO @c_Loadkey    
                                 ,@c_consigneekey    
                                 ,@c_SortLocType    
                                 ,@c_PickType    
                                 ,@c_PickZone    
                                 ,@c_ConsoOrderkey    
                                 ,@c_PickHeaderKey    
    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      BEGIN TRAN    
    
   IF @b_debug='1'    
   BEGIN    
         
     SELECT 'Get Pickheaderkey' , @c_PickHeaderKey '@c_PickHeaderKey', @c_LoadKey '@c_LoadKey'    
   END    
    
      IF @c_PickHeaderKey = ''    
      BEGIN    
         SET @c_PickHeaderKey = 'P' + @c_PickSlipNo    
    
         IF @b_debug='1'    
         BEGIN    
           SELECT 'INSERT PICKHEADER' , @c_PickHeaderKey '@c_PickHeaderKey', @c_LoadKey '@c_LoadKey', @c_ConsoOrderkey '@c_ConsoOrderkey'    
         END    
           
         INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, ConsoOrderkey, PickType, Zone, TrafficCop)    
         VALUES (@c_PickHeaderKey, @c_LoadKey,@c_ConsoOrderkey, '0', 'LB', NULL)    
    
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
          
         IF @b_debug='1'    
         BEGIN    
           SELECT 'UPDATE PICKHEADER' , @c_PickHeaderKey '@c_PickHeaderKey', @c_LoadKey '@c_LoadKey'    
         END    
    
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
            , TPK.InnerPack  
      FROM #TMP_PCK TPK    
      JOIN ORDERS     OH   WITH (NOLOCK) ON (TPK.Loadkey  = OH.Loadkey)    
      JOIN PICKDETAIL PD   WITH (NOLOCK) ON (OH.Orderkey  = PD.Orderkey)    
                                         AND(TPK.Storerkey= PD.Storerkey)    
                                         AND(TPK.Sku = PD.Sku)    
                                         AND(TPK.Loc = PD.Loc)    
                                         AND(TPK.ID  = PD.ID)    
                                         --AND(TPK.Pickdetailkey = CASE WHEN @n_LinkPickdetailkey = 1 THEN PD.PickDetailKey ELSE TPK.Pickdetailkey END )     
                                         AND(TPK.Pickdetailkey =  PD.PickDetailKey)        
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
                                 ,@n_innerpack   
    
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
  
    IF @b_debug='1'  and @c_PickDetailKey = '0001476950'  
          BEGIN    
             SELECT 'check pickdetail' , @c_PickDetailKey '@c_PickDetailKey', @c_PickType '@c_PickType'  , @n_Qty '@n_Qty',@n_CaseCnt '@n_CaseCnt', @n_innerpack '@n_innerpack'  
          END    
             
         IF @c_PickType IN ( 'PPLC', 'LC') AND (@n_Qty > @n_CaseCnt OR @n_Qty >@n_innerpack)   
         BEGIN    
            GOTO NEXT_PD    
         END    
  
    IF @b_debug='1'  and @c_PickDetailKey = '0001476950'  
          BEGIN    
             SELECT 'check next pickdetail' , @c_PickDetailKey '@c_PickDetailKey', @c_PickType '@c_PickType'    
          END    
    
         IF EXISTS ( SELECT 1    
                     FROM REFKEYLOOKUP WITH (NOLOCK)    
                     WHERE Pickdetailkey = @c_PickDetailKey    
                  )    
         BEGIN    
            IF @b_debug='1'    
            BEGIN    
              SELECT 'UPDATE REFKEYLOOKUP' , @c_PickDetailKey '@c_PickDetailKey', @c_PickHeaderKey '@c_PickHeaderKey'    
            END    
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
          
             IF @b_debug='1'    
             BEGIN    
                SELECT 'INSERT REFKEYLOOKUP' , @c_PickDetailKey '@c_PickDetailKey', @c_PickHeaderKey '@c_PickHeaderKey',@c_OrderKey '@c_OrderKey'    
                    ,@c_OrderLineNumber '@c_OrderLineNumber',@c_loadkey '@c_loadkey'    
              END    
    
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
          
            IF @b_debug='1'    
            BEGIN    
              SELECT 'UPDATE PICKDETAIL' , @c_PickDetailKey '@c_PickDetailKey', @c_PickHeaderKey '@c_PickHeaderKey'    
            END     
           
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
                                    ,@n_innerpack    
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
                                    ,@c_consigneekey    
                                    ,@c_SortLocType    
                                    ,@c_PickType    
                                    ,@c_PickZone    
                                    ,@c_ConsoOrderkey    
                                    ,@c_PickHeaderKey    
    
   END    
   CLOSE CUR_PSLIP    
   DEALLOCATE CUR_PSLIP    
    
   INSERT INTO #TMP_PKPAGE    
   ( PageGroup    
      , Loadkey             
      , PickSlipNo          
      , PrintedFlag         
      , LoadExtOrderkey         
      , ConsoOrderkey       
      , consigneekey          
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
      , TotalCases           
      , Pickdetailkey      
      , CCompany    
      , CCity    
      , InnerPack  
      , QtyInInner    
      )    
   SELECT CEILING(((ROW_NUMBER() OVER (PARTITION BY PickSlipNo ORDER BY TPK.Loadkey    
                                    ,  TPK.consigneekey    
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
                                    ,  TPK.LoadExtOrderkey         
                                    ,  TPK.ConsoOrderkey       
                                    ,  TPK.consigneekey          
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
                    ,  TPK.TotalCases             
                                    ,  TPK.Pickdetailkey      
                                    ,  TPK.CCompany    
                                    ,  TPK.CCity   
                                    ,  TPK.InnerPack  
                                    ,  TPK.QtyInInner      
   FROM #TMP_PCK TPK     
   ORDER BY TPK.Loadkey    
      ,  TPK.consigneekey    
      ,  TPK.PickZone    
      ,  TPK.SortLocType     
      ,  TPK.PickType    
      ,  TPK.PickSlipNo    
      ,  TPK.LogicalLocation       
      ,  TPK.Loc      
      ,  TPK.Storerkey    
      ,  TPK.Sku    
    
   INSERT INTO #TMP_PAGING    
      (  Loadkey       
      ,  PickSlipNo    
      ,  consigneekey    
      ,  PickZone    
      ,  SortLocType    
      ,  PickType    
      ,  PageGroup    
      ,  PageNo    
      )    
   SELECT DISTINCT    
         TPKPG.Loadkey       
      ,  TPKPG.PickSlipNo    
      ,  TPKPG.consigneekey    
      ,  TPKPG.PickZone    
      ,  TPKPG.SortLocType    
      ,  TPKPG.PickType    
      ,  TPKPG.PageGroup    
      ,  PageNo = DENSE_RANK() OVER (PARTITION BY     
                                      TPKPG.Loadkey    
                                    , TPKPG.consigneekey    
                                      ORDER BY     
                                      TPKPG.Loadkey    
                                    , TPKPG.consigneekey    
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
    
   WHILE @@TRANCOUNT < @n_StartTCnt    
   BEGIN    
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
                                 AND   TPKPG.consigneekey = #TMP_PAGING.consigneekey     
                              ),0)    
         ,TPKPG.Loadkey    
         ,TPKPG.consigneekey     
         ,TPKPG.LoadExtOrderkey      
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
         ,TPKPG.TotalCases                          
         ,@n_ShowTotalCases AS ShowTotalCases         
         ,@n_ShowGrandTotal AS ShowGrandTotal     
         ,TPKPG.CCompany        
         ,TPKPG.CCity    
         ,TPKPG.QtyInInner  
   FROM #TMP_PKPAGE TPKPG    
   LEFT JOIN #TMP_PAGING PG ON ( TPKPG.Loadkey    = PG.Loadkey )      
                            AND( TPKPG.PickSlipNo = PG.PickSlipNo )      
                            AND( TPKPG.consigneekey = PG.consigneekey )      
                            AND( TPKPG.PickZone   = PG.PickZone )      
                            AND( TPKPG.SortLocType= PG.SortLocType )       
                            AND( TPKPG.PickType   = PG.PickType )       
                            AND( TPKPG.PageGroup  = PG.PageGroup )      
   WHERE TPKPG.PickSlipNo <> ''     
   ORDER BY TPKPG.RowNo    
END -- procedure    

GO