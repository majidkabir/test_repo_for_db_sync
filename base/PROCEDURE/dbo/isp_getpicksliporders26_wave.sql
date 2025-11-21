SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_GetPickSlipOrders26_wave                       */
/* Creation Date:  16-AUG-2013                                          */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#286584 & SOS#288327 - CPPI - New Consolidated Picklist  */
/*        : for CPPI                                                    */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1 (Unicode)                                          */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 10-SEP-2013  YTWan   1.1   SOS#288327 - fixed (Wan01)                */ 
/* 10-SEP-2013  YTWan   1.1   SOS#288327 - CR (Wan02)                   */ 
/* 28-APR-2015  NJOW01  2.2   339791-Add trfroom                        */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders26_wave] (
            @c_Wavekey          NVARCHAR(10)
            )
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET NOCOUNT ON 
   
   DECLARE @b_debug           INT 
         , @n_StartTCnt       INT   
         , @n_continue        INT  
         , @b_success         INT  
         , @n_err             INT
         , @c_errmsg          NVARCHAR(255)

   
         , @c_pickheaderkey   NVARCHAR(10) 
         , @c_PickslipNo      NVARCHAR(10)  
         , @c_PrintedFlag     NVARCHAR(1)  
         , @c_PrevPickslipNo  NVARCHAR(10)  
         , @c_PickUOM         NVARCHAR(5)  
         , @c_PickZone        NVARCHAR(10)  
         , @c_PickType        NVARCHAR(30)
         , @c_C_Company       NVARCHAR(45)
         , @d_LoadDate        DATETIME      
   
         , @c_Loadkey         NVARCHAR(10)      
         , @c_Orderkey        NVARCHAR(10)        
         , @c_OrderLineNumber NVARCHAR(5) 
         , @c_PickDetailkey   NVARCHAR(10)      
         , @c_Storerkey       NVARCHAR(15)        
         , @c_sku             NVARCHAR(20)  
         , @c_SkuDescr        NVARCHAR(60)  
         , @c_Loc             NVARCHAR(10)  
         , @c_LogicalLoc      NVARCHAR(18)  
         , @c_LocType         NVARCHAR(10)  
         , @c_ID              NVARCHAR(18)
         , @c_Lottable02label NVARCHAR(30)
         , @c_Lottable04Label NVARCHAR(30)       
         , @c_Lottable02      NVARCHAR(18)  
         , @d_Lottable04      DATETIME  
         , @n_Palletcnt       INT  
         , @n_Cartoncnt       INT 
         , @n_EA              INT 
         , @n_TotalCarton     FLOAT  
         , @n_Pallet          INT  
         , @n_Casecnt         INT  
         , @n_Qty             INT  
         , @n_PageNo          INT  
         , @c_TotalPage       INT
         , @c_TrfRoom         NVARCHAR(10) --NJOW01
         


   SET @n_StartTCnt  = @@TRANCOUNT
   SET @n_continue   = 1 
   SET @b_Debug      = 0  

   DECLARE @t_Result TABLE 
         (  
            Loadkey     NVARCHAR(10) 
         ,  Pickslipno  NVARCHAR(10) 
         ,  PickType    NVARCHAR(30) 
         ,  LoadingDate DATETIME 
         ,  PickZone    NVARCHAR(10) 
         ,  C_Company   NVARCHAR(45)
         ,  Loc         NVARCHAR(10) 
         ,  Logicalloc  NVARCHAR(18) 
         ,  Storerkey   NVARCHAR(15)
         ,  SKU         NVARCHAR(20)   
         ,  Descr       NVARCHAR(60)    
         ,  Palletcnt   INT  
         ,  Cartoncnt   INT  
         ,  EA          INT
         ,  TotalCarton FLOAT  
         ,  ID          NVARCHAR(18)                         
         ,  Lottable02  NVARCHAR(18)                       
         ,  Lottable04  DATETIME
         ,  ReprintFlag NVARCHAR(1)   
         ,  PageNo      INT  
         ,  TotalPage   INT     
         ,  TrfRoom     NVARCHAR(10) NULL --NJOW01
         ,  rowid       INT IDENTITY(1,1)
         )  
   

   DECLARE WAVE_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT DISTINCT LOADPLANDETAIL.Loadkey
   FROM WAVEDETAIL     WITH (NOLOCK)
   JOIN ORDERS         WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)
   JOIN LOADPLANDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = LOADPLANDETAIL.Orderkey)
   WHERE WAVEDETAIL.Wavekey = @c_wavekey

   OPEN WAVE_CUR  
  
   FETCH NEXT FROM WAVE_CUR INTO @c_Loadkey
           
   WHILE (@@FETCH_STATUS <> -1) AND (@n_continue = 1 OR @n_continue = 2)     
   BEGIN                
      IF EXISTS(SELECT 1 FROM PICKHEADER WITH (NOLOCK) WHERE ExternOrderKey = @c_loadkey AND Zone = 'LB')  
         SET @c_PrintedFlag = 'Y'  
      ELSE  
         SET @c_PrintedFlag = 'N'  
      
      BEGIN TRAN  
      
      -- Uses PickType as a Printed Flag  
      UPDATE PICKHEADER WITH (ROWLOCK)  
      SET   PickType = '1',  
          TrafficCop = NULL  
      WHERE ExternOrderKey = @c_loadkey  
      AND   Zone = 'LB'  
      AND   PickType = '0' 
       
      IF @@ERROR <> 0   
      BEGIN  
         SET @n_continue = 3  
         SET @n_err=73000   
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed On Table Pickheader Table. (isp_GetPickSlipOrders26_wave)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
         GOTO EXIT_SP
      END  
     
     
      IF @n_continue = 1 OR @n_continue = 2  
      BEGIN  
         DECLARE pickslip_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
         SELECT LOADPLAN.Loadkey
               ,ISNULL(RTRIM(LOC.LocationType),'')
               ,LOADPLAN.AddDate
               ,ISNULL(RTRIM(LOC.PickZone),'')
               ,ISNULL(RTRIM(ORDERS.C_Company),'')    
               ,PICKDETAIL.Loc
               ,ISNULL(RTRIM(LOC.LogicalLocation),'')
               ,PICKDETAIL.Storerkey
               ,PICKDETAIL.Sku
               ,MAX(ISNULL(RTRIM(SKU.Descr),''))
               ,PICKDETAIL.ID
               ,ISNULL(RTRIM(LA.Lottable02),'')
               ,ISNULL(LA.Lottable04, 1900-01-01)
               ,ISNULL(PACK.Pallet,0)       
               ,ISNULL(PACK.Casecnt,0)        
               ,SUM(PickDetail.Qty)
               ,LOADPLAN.Trfroom --NJOW01
         FROM  PICKDETAIL      WITH (NOLOCK) 
         JOIN  ORDERS          WITH (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERS.Orderkey) 
         JOIN  LOADPLANDETAIL  WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = PICKDETAIL.Orderkey)  
         JOIN  LOADPLAN        WITH (NOLOCK) ON (LOADPLAN.Loadkey = LOADPLANDETAIL.Loadkey)  
         JOIN  LOC             WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)  
         JOIN  SKU             WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.SKU = SKU.SKU)  
         JOIN  PACK            WITH (NOLOCK) ON (PACK.Packkey = SKU.Packkey)  
         JOIN  LOTATTRIBUTE LA WITH (NOLOCK) ON (PICKDETAIL.Lot = LA.Lot)  
         WHERE LOADPLAN.Loadkey = @c_Loadkey  
         AND   PICKDETAIL.Status < '5'  
         GROUP BY LOADPLAN.Loadkey           
               ,ISNULL(RTRIM(LOC.LocationType),'')
               ,LOADPLAN.AddDate
               ,ISNULL(RTRIM(LOC.PickZone),'')
               ,ISNULL(RTRIM(ORDERS.C_Company),'')      
               ,PICKDETAIL.Loc
               ,ISNULL(RTRIM(LOC.LogicalLocation),'')
               ,PICKDETAIL.Storerkey
               ,PICKDETAIL.Sku
               ,PICKDETAIL.ID
               ,ISNULL(RTRIM(LA.Lottable02),'')
               ,ISNULL(LA.Lottable04, 1900-01-01)
               ,ISNULL(PACK.Pallet,0)       
               ,ISNULL(PACK.Casecnt,0)
               ,LOADPLAN.Trfroom --NJOW05               
       ORDER BY ISNULL(RTRIM(LOC.PickZone),'')
               ,ISNULL(RTRIM(LOC.LogicalLocation),'')
               ,Pickdetail.Loc
               ,Pickdetail.SKU  
    
     
        OPEN pickslip_cur  
        
        FETCH NEXT FROM pickslip_cur INTO @c_Loadkey
                                       ,  @c_LocType
                                       ,  @d_LoadDate
                                       ,  @c_PickZone
                                       ,  @c_C_Company
                                       ,  @c_Loc
                                       ,  @c_LogicalLoc  
                                       ,  @c_Storerkey  
                                       ,  @c_SKU
                                       ,  @c_SkuDescr
                                       ,  @c_ID
                                       ,  @c_Lottable02
                                       ,  @d_Lottable04
                                       ,  @n_Pallet
                                       ,  @n_Casecnt
                                       ,  @n_Qty  
                                       ,  @c_TrfRoom --NJOW01

          
         WHILE (@@FETCH_STATUS <> -1) AND (@n_continue = 1 OR @n_continue = 2)     
         BEGIN  

            SET @n_Palletcnt = 0  
            SET @n_Cartoncnt = 0  
            SET @n_EA        = 0
            SET @n_TotalCarton = 0.00  
        
            SET @n_TotalCarton = CASE WHEN @n_Casecnt > 0 THEN @n_Qty / @n_Casecnt 
                                      ELSE 0
                                      END

            IF UPPER(@c_PickZone) <> 'BULK' 
            BEGIN
               SET @c_PickType = 'PICKING AREA'
               --(Wan02) - START
               --SET @n_EA = CASE WHEN @c_LocType = 'PICK' THEN @n_Qty ELSE 0 END
               --SET @n_Cartoncnt = CASE WHEN @c_LocType = 'CASE'   AND @n_CaseCnt > 0
               --                        THEN @n_Qty / @n_CaseCnt ELSE 0 END
               --SET @n_Palletcnt = CASE WHEN @c_LocType = 'PALLET' AND @n_Pallet > 0
               --                        THEN @n_Qty/@n_Pallet ELSE 0 END
               --(Wan02) - END
            END
            ELSE
            BEGIN
               IF @n_Qty >= @n_Pallet  
               BEGIN
                  SET @c_PickType = 'FULL PALLET PICK' 
                  --SET @n_Palletcnt = CASE WHEN @n_Pallet > 0 THEN FLOOR(@n_Qty / @n_Pallet) ELSE 0 END    --(Wan02)
               END
               ELSE
               BEGIN
                  SET @c_PickType = 'CASE PICK' 
                  --SET @n_Cartoncnt = CASE WHEN @n_CaseCnt > 0 THEN FLOOR(@n_Qty / @n_CaseCnt) ELSE 0 END  --(Wan02)
               END
            END

            --(Wan02) - START
            SET @n_Palletcnt = CASE WHEN @n_Pallet > 0 THEN @n_Qty/@n_Pallet ELSE 0 END
            SET @n_Cartoncnt = CASE WHEN @n_CaseCnt> 0 THEN (@n_Qty - (@n_Palletcnt * @n_Pallet))/@n_CaseCnt ELSE 0 END
            SET @n_EA        = @n_Qty - (@n_Palletcnt * @n_Pallet) - (@n_Cartoncnt * @n_CaseCnt)
            --(Wan02) - END

            INSERT INTO @t_Result 
                     (
                        Loadkey
                     ,  Pickslipno
                     ,  PickType
                     ,  LoadingDate
                     ,  PickZone
                     ,  C_Company
                     ,  Loc
                     ,  LogicalLoc
                     ,  Storerkey
                     ,  SKU
                     ,  Descr
                     ,  Palletcnt
                     ,  Cartoncnt
                     ,  EA
                     ,  TotalCarton
                     ,  ID
                     ,  Lottable02
                     ,  Lottable04
                     ,  ReprintFlag
                     ,  PageNo
                     ,  TotalPage
                     ,  TrfRoom --NJOW01
                     )  
            VALUES   (  @c_Loadkey
                     ,  ''
                     ,  @c_PickType
                     ,  @d_LoadDate
                     ,  @c_PickZone
                     ,  @c_C_Company
                     ,  @c_LOC
                     ,  @c_LogicalLoc
                     ,  @c_Storerkey
                     ,  @c_SKU
                     ,  @c_SkuDescr  
                     ,  @n_Palletcnt
                     ,  @n_Cartoncnt
                     ,  @n_EA
                     ,  @n_TotalCarton
                     ,  @c_ID
                     ,  @c_Lottable02
                     ,  @d_Lottable04
                     ,  @c_PrintedFlag
                     ,  0
                     ,  0
                     ,  @c_TrfRoom --NJOW01
                     )  
     
           FETCH NEXT FROM pickslip_cur INTO @c_Loadkey
                                          ,  @c_LocType
                                          ,  @d_LoadDate
                                          ,  @c_PickZone
                                          ,  @c_C_Company
                                          ,  @c_Loc
                                          ,  @c_LogicalLoc 
                                          ,  @c_Storerkey     
                                          ,  @c_SKU
                                          ,  @c_SkuDescr
                                          ,  @c_ID
                                          ,  @c_Lottable02
                                          ,  @d_Lottable04
                                          ,  @n_Pallet
                                          ,  @n_Casecnt
                                          ,  @n_Qty
                                          ,  @c_TrfRoom --NJOW01
         END /* While */  
        
         CLOSE pickslip_cur  
         DEALLOCATE pickslip_cur  
      END /* @n_Continue = 1 */  
     
      IF @b_Debug = 1  
      BEGIN  
         SELECT * FROM @t_Result  
         
         SELECT PickType, PickZone  
         FROM   @t_Result  
         WHERE  Pickslipno = ''  
         GROUP BY PickType
                , PickZone  
         ORDER BY CASE WHEN PickType = 'PICKING AREA' THEN '1'   
                       WHEN PickType = 'FULL PALLET PICK' THEN '2' ELSE '3' END  
      END   
     
      IF @n_continue = 1 OR @n_continue = 2  
      BEGIN  
         DECLARE PickType_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
         SELECT PickType
               ,PickZone  
         FROM   @t_Result  
         WHERE  Pickslipno = ''  
         GROUP BY PickType, PickZone  
         ORDER BY CASE WHEN PickType = 'PICKING AREA' THEN '1'   
                       WHEN PickType = 'FULL PALLET PICK' THEN '2' ELSE '3' END  
     
         OPEN PickType_cur  
     
         FETCH NEXT FROM PickType_cur INTO @c_PickType
                                          ,@c_PickZone  
         
         WHILE (@@FETCH_STATUS <> -1) AND (@n_continue = 1 OR @n_continue = 2)     
         BEGIN    
            SET @c_pickheaderkey = ''  
            SET @c_WaveKey = ''

            IF @c_PickZone = 'BULK'   
            BEGIN  
               IF @c_PickType = 'FULL PALLET PICK'  
               BEGIN   
                  SELECT @c_pickheaderkey = PickHeaderKey  
                  FROM  PICKHEADER WITH (NOLOCK)   
                  WHERE ExternOrderKey = @c_loadkey   
                   AND  WaveKey = RTRIM(@c_PickZone) + '_P'   
                   AND  Zone = 'LB'  

                  SET @c_WaveKey = RTRIM(@c_PickZone) + '_P'   
               END   
               ELSE  
               BEGIN   
                  SELECT @c_pickheaderkey = PickHeaderKey  
                  FROM  PICKHEADER WITH (NOLOCK)   
                  WHERE ExternOrderKey = @c_loadkey   
                   AND  WaveKey = RTRIM(@c_PickZone) + '_C'    
                   AND  Zone = 'LB' 
                    
                  SET @c_WaveKey = RTRIM(@c_PickZone) + '_C'  
               END   
            END  
            ELSE  
            BEGIN  
               SELECT @c_pickheaderkey = PickHeaderKey  
               FROM  PICKHEADER WITH (NOLOCK)   
               WHERE ExternOrderKey = @c_loadkey   
                AND  WaveKey = @c_PickZone  
                AND  Zone = 'LB'  
            
               SET @c_WaveKey = RTRIM(@c_PickZone)   
            END  
     
            -- Only insert the First Pickslip# in PickHeader  
            IF ISNULL(RTRIM(@c_pickheaderkey), '') = ''   
            BEGIN     
               EXECUTE nspg_GetKey  
                        'PICKSLIP'  
                     ,  9    
                     ,  @c_pickheaderkey  OUTPUT  
                     ,  @b_success        OUTPUT   
                     ,  @n_err            OUTPUT  
                     ,  @c_errmsg         OUTPUT  
                  
               SET @c_pickheaderkey = 'P' + @c_pickheaderkey   
              
               INSERT INTO PICKHEADER  
                     (  
                        PickHeaderKey
                     ,  OrderKey
                     ,  ExternOrderKey
                     ,  PickType
                     ,  Zone
                     ,  TrafficCop
                     ,  WaveKey
                     )  
               VALUES  
                     (
                        @c_pickheaderkey
                     ,  ''
                     ,  @c_LoadKey
                     ,  '0'
                     ,  'LB'
                     ,  ''
                     , @c_WaveKey )   
              
               SET @n_err = @@ERROR 
    
               IF @n_err <> 0  
               BEGIN  
                  SET @n_continue = 3  
                  SET @n_err=73001     
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Failed On Table PICKHEADER. (isp_GetPickSlipOrders26_wave)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
                  GOTO EXIT_SP
               END  
            END  
     
            IF @n_Continue = 1 OR @n_Continue = 2  
            BEGIN  
               UPDATE @t_Result  
               SET    PickSlipno = @c_pickheaderkey  
               WHERE  Pickslipno = ''  
               AND    PickType = @c_PickType  
               AND    PickZone = @c_PickZone  
            
               -- Get PickDetail records for each Pick Ticket (Picking Area / Full Pallet / Case Pick)  
               DECLARECURSOR_PickDet:  
               IF @c_PickType = 'PICKING AREA'   
               BEGIN  
                  DECLARE PickDet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
                  SELECT PICKDETAIL.Pickdetailkey
                        ,PICKDETAIL.Orderkey
                        ,PICKDETAIL.OrderLineNumber  
                  FROM   PICKDETAIL     WITH (NOLOCK)       
                  JOIN   LOADPLANDETAIL WITH (NOLOCK) ON (PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey)  
                  JOIN   LOC            WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)  
                  WHERE  LOADPLANDETAIL.Loadkey = @c_Loadkey  
                  AND    (LOC.LocationType = 'CASE' OR LOC.LocationType = 'PICK' OR LOC.LocationType = 'PALLET' )  --(Wan01)
                  AND    LOC.PickZone = @c_PickZone  
                  AND    PICKDETAIL.Status < '5'  
                  ORDER BY Pickdetailkey       
               END     
               ELSE IF @c_PickType = 'FULL PALLET PICK'  
               BEGIN  
                  DECLARE PickDet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
                  SELECT PickDetail.Pickdetailkey, PickDetail.Orderkey, PickDetail.OrderLineNumber  
                  FROM   PICKDETAIL      WITH (NOLOCK)       
                  JOIN   LOADPLANDETAIL  WITH (NOLOCK) ON (PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey)    
                  JOIN   LOTATTRIBUTE LA WITH (NOLOCK) ON (PICKDETAIL.Lot = LA.Lot)  
                  JOIN   @t_Result RESULT              ON (PICKDETAIL.Storerkey = RESULT.Storerkey) 
                                                       AND(PICKDETAIL.SKU = RESULT.SKU)    
                                                       AND(PICKDETAIL.Loc = RESULT.Loc)   
                                                       AND(PICKDETAIL.ID  = RESULT.ID)   
                                                       AND(LA.Lottable02  = RESULT.Lottable02)   
                                                       AND(LA.Lottable04  = RESULT.Lottable04)   
                  WHERE  LoadPlanDetail.Loadkey = @c_Loadkey  
                  AND    RESULT.PickType = 'FULL PALLET PICK'  
                  AND    Pickdetail.Status < '5'  
                  ORDER BY Pickdetailkey     
               END -- 'Full Pallet Pick'    
               ELSE IF @c_PickType = 'CASE PICK'  
               BEGIN  
                  DECLARE PickDet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
                  SELECT PICKDETAIL.Pickdetailkey
                        ,PICKDETAIL.Orderkey
                        ,PICKDETAIL.OrderLineNumber  
                  FROM   PICKDETAIL      WITH (NOLOCK)       
                  JOIN   LOADPLANDETAIL  WITH (NOLOCK) ON (PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey)   
                  JOIN   LOTATTRIBUTE LA WITH (NOLOCK) ON (PICKDETAIL.Lot = LA.Lot)
                  JOIN   @t_Result RESULT              ON (PICKDETAIL.Storerkey = RESULT.Storerkey) 
                                                       AND(PICKDETAIL.SKU = RESULT.SKU)  
                                                       AND(PICKDETAIL.Loc = RESULT.Loc)  
                                                       AND(PICKDETAIL.ID = RESULT.ID) 
                                                       AND(LA.Lottable02 = RESULT.Lottable02)  
                                                       AND(LA.Lottable04 = RESULT.Lottable04)  
                  WHERE  LoadPlanDetail.Loadkey = @c_Loadkey  
                  AND    RESULT.PickType = 'CASE PICK'  
                  AND    Pickdetail.Status < '5'  
                  ORDER BY Pickdetailkey     
               END -- 'CASE PICK'  
        
               OPEN PickDet_cur  
               SET @n_err = @@ERROR  
        
               IF @n_err = 16905  
               BEGIN  
                  CLOSE PickDet_cur  
                  DEALLOCATE PickDet_cur  
                  GOTO DECLARECURSOR_PickDet  
               END  
        
               IF @n_err = 16915  
               BEGIN  
                  CLOSE PickDet_cur  
                  DEALLOCATE PickDet_cur  
                  GOTO DECLARECURSOR_PickDet  
               END  
        
               IF @n_err = 16916  
               BEGIN  
                  GOTO EXIT_SP  
               END  
      
               FETCH NEXT FROM PickDet_cur INTO @c_Pickdetailkey
                                             ,  @c_Orderkey
                                             ,  @c_OrderLineNumber   
      
               WHILE (@@FETCH_STATUS <> -1) AND (@n_continue = 1 OR @n_continue = 2)     
               BEGIN    
                  IF NOT EXISTS (SELECT 1 FROM REFKEYLOOKUP WITH (NOLOCK) WHERE Pickdetailkey = @c_PickDetailkey)  
                  BEGIN  
                     INSERT INTO REFKEYLOOKUP (Pickdetailkey, Pickslipno, Orderkey, OrderLineNumber, Loadkey)  
                     VALUES (@c_PickDetailkey, @c_pickheaderkey, @c_OrderKey, @c_OrderLineNumber, @c_loadkey)  
     
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @n_continue = 3  
                        SET @n_err=73002     
                        SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Failed On Table RefkeyLookup. (isp_GetPickSlipOrders26_wave)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
                        GOTO EXIT_SP
                     END      
     
                     IF (@n_continue = 1 OR @n_continue = 2)  
                     BEGIN  
                        UPDATE PICKDETAIL WITH (ROWLOCK)  
                        SET    PickSlipNo = @c_pickheaderkey
                              ,TrafficCop = Null 
                              ,EditWho = SUSER_NAME()
                              ,EditDate= GETDATE() 
                        WHERE  PickDetailkey = @c_PickDetailkey
                          
                        IF @@ERROR <> 0  
                        BEGIN  
                           SET @n_continue = 3  
                           SET @n_err=73003    
                           SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed On Table PICKDETAIL. (isp_GetPickSlipOrders26_wave)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
                           GOTO EXIT_SP
                        END      
                     END  
                  END  
          
                  FETCH NEXT FROM PickDet_cur INTO @c_Pickdetailkey
                                                ,  @c_Orderkey
                                                ,  @c_OrderLineNumber  
               END  
               CLOSE pickdet_cur  
               DEALLOCATE pickdet_cur      
            END -- Continue = 1  
      
            FETCH NEXT FROM PickType_cur INTO @c_PickType, @c_PickZone  
         END -- While : Get Pickslip#  
         CLOSE PickType_cur  
         DEALLOCATE PickType_cur  
      END
 
      COMMIT TRAN 
      FETCH NEXT FROM WAVE_CUR INTO @c_Loadkey  
   END
   CLOSE WAVE_CUR
   DEALLOCATE WAVE_CUR

   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      -- Assign Page No    
      SET @c_PrevPickslipNo = ''  
      SET @c_TotalPage = 0  
      SET @n_PageNo = 1  
  
      DECLARE C_PageNo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT Distinct PickslipNo  
      FROM   @t_Result     
      ORDER BY PickslipNo        
      OPEN C_PageNo  
           
      FETCH NEXT FROM C_PageNo INTO @c_PickslipNo   
           
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         IF @c_PickslipNo <> @c_PrevPickslipNo  
         BEGIN  
          -- SET @n_PageNo = 1  
            WHILE 1 = 1  
            BEGIN              
               IF NOT EXISTS (SELECT 1 FROM @t_Result   
                              WHERE PickslipNo = @c_PickslipNo                             
                              AND   PageNo = 0 )  
               BEGIN  
                  SET RowCount 0  
                  BREAK  
               END  
   
               SET RowCount 20  
  
               UPDATE @t_Result  
               SET   PageNo = @n_PageNo  
               WHERE PickslipNo = @c_PickslipNo  
               AND   PageNo = 0   
  
  
               SET  @n_PageNo    = @n_PageNo + 1  
               SET  @c_TotalPage = @c_TotalPage + 1  
               SET  RowCount 0      
            END -- end while 1=1     
         END  
  
         FETCH NEXT FROM C_PageNo INTO @c_PickslipNo  
      END   
      CLOSE C_PageNo  
      DEALLOCATE C_PageNo   
  
      -- Update Totalpage  
      UPDATE @t_Result  
      SET   TotalPage = @c_TotalPage  
      WHERE TotalPage = 0     
  
      SELECT TOP 1 @c_Storerkey = Storerkey 
      FROM ORDERS WITH (NOLOCK)
      WHERE Loadkey = @c_Loadkey
  
      SELECT @c_Lottable02label = ISNULL(RTRIM(Description),'')
      FROM CODELKUP WITH (NOLOCK) 
      WHERE Code = 'Lottable02'
      AND Listname = 'RPTCOLHDR'
      AND Storerkey = @c_Storerkey
      
      SELECT @c_Lottable04label = ISNULL(RTRIM(Description),'') 
      FROM CODELKUP WITH (NOLOCK) 
      WHERE Code = 'Lottable04'
      AND Listname = 'RPTCOLHDR'
      AND Storerkey = @c_Storerkey
      
      IF ISNULL(@c_Lottable02label,'') = ''
         SET @c_Lottable02label = 'Batch No'
      
      IF ISNULL(@c_Lottable04label,'') = ''
         SET @c_Lottable04label = 'Exp Date'
      
      SELECT Loadkey     
         ,  Pickslipno   
         ,  PickType     
         ,  LoadingDate  
         ,  PickZone     
         ,  Loc          
         ,  Logicalloc   
         ,  SKU           
         ,  Descr            
         ,  Palletcnt    
         ,  Cartoncnt      
         ,  TotalCarton    
         ,  ID                                
         ,  Lottable02                      
         ,  Lottable04   
         ,  ReprintFlag   
         ,  PageNo         
         ,  TotalPage         
         ,  rowid       
         ,  SUSER_SNAME()
         ,  @c_Lottable02label
         ,  @c_Lottable04label 
         ,  C_Company
         ,  EA
         ,  TrfRoom  --NJOW01
      FROM @t_Result  
      ORDER BY PickslipNo, PageNo, RowID  
   END     
  
EXIT_SP: 
    
   IF CURSOR_STATUS('LOCAL' , 'WAVE_CUR') in (0 , 1)
   BEGIN
      CLOSE WAVE_CUR
      DEALLOCATE WAVE_CUR
   END

   IF CURSOR_STATUS('LOCAL' , 'pickslip_cur') in (0 , 1)
   BEGIN
      CLOSE pickslip_cur
      DEALLOCATE pickslip_cur
   END

   IF CURSOR_STATUS('LOCAL' , 'PickType_cur') in (0 , 1)
   BEGIN
      CLOSE PickType_cur
      DEALLOCATE PickType_cur
   END

   IF CURSOR_STATUS('LOCAL' , 'PickDet_cur') in (0 , 1)
   BEGIN
      CLOSE PickDet_cur
      DEALLOCATE PickDet_cur
   END


   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
     IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt  
     BEGIN  
        ROLLBACK TRAN  
     END  
     ELSE  
     BEGIN  
        WHILE @@TRANCOUNT > @n_starttcnt  
        BEGIN  
           COMMIT TRAN  
        END  
     END  
     EXECUTE nsp_logerror @n_err, @c_errmsg, 'Generation of Pick Slip'  
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012   
   END  
   ELSE  
   BEGIN  
     WHILE @@TRANCOUNT > @n_starttcnt  
     BEGIN  
        COMMIT TRAN  
     END  
   END  
END


GO