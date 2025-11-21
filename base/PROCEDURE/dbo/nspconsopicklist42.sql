SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: nspConsoPickList42                                  */
/* Creation Date: 07-Sep-2017                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-2777 -  [7Eleven] - New Consolidated pickslip           */
/*          (copy from nspConsoPickList22)                              */
/* Input Parameters: @as_LoadKey - (LoadKey)                            */
/*                                                                      */
/* Called By: r_dw_consolidated_pick42                                  */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author  Ver. Purposes                                    */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[nspConsoPickList42] (@as_LoadKey NVARCHAR(10) )
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @n_starttrancnt  INT,
      @n_continue      INT,
      @b_success       INT,
      @n_err           INT,
      @c_errmsg        NVARCHAR(255)

   DECLARE
      @c_PrintedFlag   NVARCHAR(1),
      --@c_PickHeaderKey NVARCHAR(10),
      @c_LocTypeDesc           NVARCHAR(20),       
      @c_Pickdetailkey         NVARCHAR(10),       
      @c_PrevLoadkey           NVARCHAR(10),       
      @c_PrevLocTypeDesc       NVARCHAR(20),       
      @c_Pickslipno            NVARCHAR(10),       
      @c_Orderkey              NVARCHAR(10),       
      @c_Orderlinenumber       NVARCHAR(5),        
      @c_LocTypeCriteria       NVARCHAR(255),      
      @c_ExecStatement         NVARCHAR(4000),      
      @c_Pickzone              NVARCHAR(10),  
      @c_PrevPickzone          NVARCHAR(10),  
      @n_Linecount             INT,  
      @c_sku                   NVARCHAR(20),  
      @c_loc                   NVARCHAR(10),  
      @c_id                    NVARCHAR(18),  
      @c_lottable01            NVARCHAR(18),  
      @c_lottable02            NVARCHAR(18),  
      @dt_lottable04           DATETIME,      
      @c_LogicalLoc            NVARCHAR(18),   
      @c_NOSPLITBYLINECNTZONE  NVARCHAR(10),
      @c_SKUGRP                NVARCHAR(10),  
      @c_PrevSKUGRP            NVARCHAR(10),
      @c_ExecArguments         NVARCHAR(4000),
      @dt_RecvDate             DATETIME,
      @c_SSUSR3                NVARCHAR(18)     

   SELECT @n_starttrancnt = @@TRANCOUNT, @n_continue = 1
   
   SET @c_PrevLoadkey = ''
   SET @c_PrevSKUGRP = ''
   SET @c_PrevPickzone = ''

   /********************************/
   /* Use Zone as a UOM Picked     */
   /* 1 = Pallet                   */
   /* 2 = Case                     */
   /* 6 = Each                     */
   /* 7 = Consolidated pick list   */
   /* 8 = By Order                 */
   /********************************/

  
   --check if the loadplan already printed other pickslip type then return error to reject.
   IF EXISTS (SELECT PICKHEADERKEY FROM PICKHEADER WITH (NOLOCK)
          WHERE ExternOrderKey = @as_LoadKey
          AND ISNULL(RTRIM(OrderKey),'') <> ''
          AND ZONE = 'LP')
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 63500
      SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Pickslip already printed using Discrete option. (nspConsoPickList42)'
   END


   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      CREATE TABLE #TEMP_PICK
      (PickSlipNo       NVARCHAR(10) NULL,
       LoadKey          NVARCHAR(10) NULL,
       LOC              NVARCHAR(10) NULL,
       ID               NVARCHAR(18) NULL,
       SKU              NVARCHAR(20) NULL,
       AltSKU           NVARCHAR(20) NULL,
       SkuDesc          NVARCHAR(60) NULL,
       Qty              INT,
       PrintedFlag      NVARCHAR(1)  NULL,
       SKUGRP           NVARCHAR(20) NULL,
       Lottable01       NVARCHAR(18) NULL,
       Lottable02       NVARCHAR(18) NULL,  
       Lottable04       DATETIME NULL,
       LogicalLoc       NVARCHAR(18) NULL,
       Shelflife        INT,
       MinShelfLife     INT,
       pallet           INT,
       casecnt          INT,
       RecvDate         DATETIME NULL,
       putawayzone      NVARCHAR(10) NULL,
       c_company        NVARCHAR(45) NULL,
       c_address1       NVARCHAR(45) NULL,
       c_address2       NVARCHAR(45) NULL,
       c_address3       NVARCHAR(45) NULL,
       c_address4       NVARCHAR(45) NULL,
       c_city           NVARCHAR(45) NULL,
       c_state          NVARCHAR(45) NULL,
       c_zip            NVARCHAR(18) NULL,
       c_country        NVARCHAR(30) NULL,
       Storerkey        NVARCHAR(15) NULL,
       SSUSR3           NVARCHAR(18) NULL) 

       INSERT INTO #TEMP_PICK
            (PickSlipNo,          LoadKey,         Loc,         ID,
             SKU,                 AltSKU,          SkuDesc,       Qty,
             PrintedFlag,         SKUGRP, Lottable01, Lottable02,   Lottable04,
             LogicalLoc,         Shelflife,        Minshelflife,
             pallet,             casecnt,          RecvDate, putawayzone,
             c_company,          c_address1,       c_address2,    c_address3,       c_address4,
             c_city,             c_state,          c_zip,         c_country,  Storerkey,SSUSR3 )
          
        SELECT RefKeyLookup.PickSlipNo,
           @as_LoadKey as LoadKey,
           PickDetail.loc,
           PickDetail.id,
           PickDetail.sku,
           Sku.Altsku,
           Sku.Descr,
           SUM(PickDetail.qty) AS PQTY,
           ISNULL((SELECT Distinct 'Y' FROM PickHeader WITH (NOLOCK) WHERE PickHeaderkey = RefKeyLookup.PickSlipNo
                     AND ExternOrderkey = @as_Loadkey AND  Zone = 'LP') , 'N') AS PrintedFlag,                                                       
           --ISNULL((SELECT Distinct 'Y' FROM PICKHEADER WITH (NOLOCK) WHERE ExternOrderKey = @as_Loadkey AND  Zone = '7'), 'N') AS PrintedFlag,    
           sku.skugroup,
           LotAttribute.Lottable01,
           LotAttribute.Lottable02,  
           IsNUll(LotAttribute.Lottable04, '19000101'),
           LOC.LogicalLocation,
           SKU.Shelflife,
           STORER.Minshelflife,
           PACK.Pallet,
           PACK.CaseCnt,
           ISNUll(LotAttribute.Lottable05, '19000101'),
           LOC.PickZone,
           MAX(ISNULL(ORDERS.c_company,'')),
           MAX(ISNULL(ORDERS.c_address1,'')),
           MAX(ISNULL(ORDERS.c_address2,'')),
           MAX(ISNULL(ORDERS.c_address3,'')),
           MAX(ISNULL(ORDERS.c_address4,'')),
           MAX(ISNULL(ORDERS.c_city,'')),
           MAX(ISNULL(ORDERS.c_state,'')),
           MAX(ISNULL(ORDERS.c_zip,'')),
           MAX(ISNULL(ORDERS.c_country,'')),
           SKU.Storerkey,sku.SUSR3 
         FROM LOADPLANDETAIL WITH (NOLOCK)
         JOIN ORDERS WITH (NOLOCK) ON LOADPLANDETAIL.Orderkey = ORDERS.Orderkey
         JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey
         JOIN PICKDETAIL WITH (NOLOCK) ON ORDERDETAIL.orderkey = PICKDETAIL.Orderkey
                           AND ORDERDETAIL.Orderlinenumber = PICKDETAIL.Orderlinenumber
         JOIN LOTATTRIBUTE WITH (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
         JOIN STORER WITH (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey
         JOIN SKU WITH (NOLOCK) ON ORDERDETAIL.Storerkey = SKU.Storerkey
                           AND ORDERDETAIL.Sku = SKU.Sku
         JOIN PACK WITH (NOLOCK) ON Sku.Packkey = PACK.Packkey
         JOIN LOC WITH (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc
         LEFT OUTER JOIN RefKeyLookup (NOLOCK) ON (RefKeyLookup.PickDetailKey = PICKDETAIL.PickDetailKey)       
        WHERE PICKDETAIL.Status < '5'
        AND LOADPLANDETAIL.LoadKey = @as_LoadKey
        GROUP BY RefKeyLookup.PickSlipNo,           
           PickDetail.loc,
           PickDetail.id,
           PickDetail.sku,
           Sku.Altsku,
           Sku.Descr,
           sku.skugroup,
           LotAttribute.Lottable01,
           LotAttribute.Lottable02,  
           ISNUll(LotAttribute.Lottable04, '19000101'),
           ISNUll(LotAttribute.Lottable05, '19000101'),
           LOC.LogicalLocation,
           SKU.Shelflife,
           STORER.Minshelflife,
           PACK.Pallet,
           PACK.CaseCnt,
           LOC.PickZone,
           SKU.Storerkey ,sku.SUSR3 


      -- Uses PickType as a Printed Flag
      UPDATE PickHeader WITH (ROWLOCK) SET PickType = '1', TrafficCop = NULL
      WHERE ExternOrderKey = @as_LoadKey
      AND Zone = 'LP'

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63501
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update PICKHEADER Failed. (nspConsoPickList22)'
         GOTO FAILURE
      END

      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         SET @as_LoadKey = ''
         SET @c_PickDetailKey = ''
         SET @n_Continue = 1
         SET @c_Pickzone = ''  
         SET @n_Linecount = 0  

         DECLARE C_Loadkey_LocTypeDesc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT TP.LoadKey, TP.skugrp,
                TP.Putawayzone, TP.sku, TP.loc, TP.id, TP.lottable01, TP.lottable02, TP.lottable04  
               ,TP.LogicalLoc,TP.RecvDate,TP.SSUSR3                                                   
               ,CASE WHEN CLR.Code IS NOT NULL THEN 'Y' ELSE 'N' END AS NOSPLITBYLINECNTZONE  
         FROM   #TEMP_PICK TP
         LEFT JOIN CODELKUP CLR (NOLOCK) ON (TP.Storerkey = CLR.Storerkey AND CLR.Code = 'NOSPLITBYLINECNTZONE' 
                                             AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_consolidated_pick42' AND ISNULL(CLR.Short,'') <> 'N')  
         
         WHERE  TP.PickSlipNo IS NULL or TP.PickSlipNo = ''
         ORDER BY TP.skugrp,TP.SSUSR3,TP.sku,TP.logicalloc 

         OPEN C_Loadkey_LocTypeDesc

         FETCH NEXT FROM C_Loadkey_LocTypeDesc INTO @as_LoadKey, @c_SKUGRP,
                                                    @c_Pickzone, @c_sku, @c_loc, @c_id, @c_lottable01, @c_lottable02, @dt_lottable04  
                                                   ,@c_LogicalLoc ,@dt_RecvDate,@c_SSUSR3              
                                                   ,@c_NOSPLITBYLINECNTZONE  

         WHILE (@@Fetch_Status <> -1)
         BEGIN -- while 1

            SELECT @n_Linecount = @n_Linecount + 1  

            IF @c_PrevLoadKey <> @as_LoadKey OR
               @c_PrevSKUGRP <> @c_SKUGRP OR @c_PrevPickzone <> @c_Pickzone
              -- (@c_PrevPickzone <> @c_Pickzone AND @c_NOSPLITBYLINECNTZONE <> 'Y') OR    
              -- (@n_Linecount > 15 AND @c_NOSPLITBYLINECNTZONE <> 'Y')   
            BEGIN
               SET @c_PickSlipNo = ''
               SET @n_Linecount = 1  

               EXECUTE nspg_GetKey
                  'PICKSLIP',
                  9,
                  @c_PickSlipNo   OUTPUT,
                  @b_success      OUTPUT,
                  @n_err          OUTPUT,
                  @c_errmsg       OUTPUT

               IF @b_success = 1
               BEGIN
                  SELECT @c_PickSlipNo = 'P' + @c_PickSlipNo
                  INSERT PICKHEADER (pickheaderkey, ExternOrderkey, Zone, PickType, Wavekey)
                             VALUES (@c_PickSlipNo, @as_LoadKey, 'LP', '0',  @c_PickSlipNo)

                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 63501
                     SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert into PICKHEADER Failed. (nspConsoPickList42)'
                     GOTO FAILURE
                  END
               END -- @b_success = 1
               ELSE
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 63502
                  SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Get PSNO Failed. (nspConsoPickList42)'
                  BREAK
               END
            END -- @c_PrevLoadKey <> @as_LoadKey OR  @c_PrevLocTypeDesc <> @c_LocTypeDesc

            IF @n_Continue = 1
            BEGIN
               SET @c_LocTypeCriteria = ''
               SET @c_ExecStatement = ''
               SET @c_ExecArguments = ''

               --IF @c_LocTypeDesc = 'PALLET PICKING LIST'
               --BEGIN
               --   SET @c_LocTypeCriteria = 'AND LOC.LocationType = ''OTHER'''
               --END
               --ELSE
               --BEGIN
               --   SET @c_LocTypeCriteria = 'AND LOC.LocationType <> ''OTHER'''
               --END

               SET @c_ExecStatement = N'DECLARE C_PickDetailKey CURSOR FAST_FORWARD READ_ONLY FOR ' +
                                       'SELECT PickDetail.PickDetailKey, PickDetail.Orderkey, PickDetail.OrderLineNumber ' +
                                       'FROM   PickDetail WITH (NOLOCK) ' +
                                       'JOIN   OrderDetail WITH (NOLOCK) ' +
                                       'ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND ' +
                                       'PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber) ' +
                                       'JOIN   LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc) ' +
                                       'JOIN   LOTATTRIBUTE WITH (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot) ' +   
                                       ' WHERE  OrderDetail.LoadKey  =  @as_LoadKey  ' +
                                       N' AND LOC.PickZone = RTRIM(@c_Pickzone) ' +   
                                       N' AND Pickdetail.Sku = RTRIM(@c_Sku)  ' +   
                                       N' AND Pickdetail.Loc = RTRIM(@c_Loc)  ' +   
                                       N' AND Pickdetail.Id =  RTRIM(@c_ID) ' +   
                                       N' AND Lotattribute.Lottable01 = RTRIM(@c_Lottable01) ' +   
                                       N' AND Lotattribute.Lottable02 = + RTRIM(@c_Lottable02) ' +   
                                       ' AND CONVERT(CHAR(10),ISNULL(Lotattribute.Lottable04,''19000101''),112) =  CONVERT(CHAR(10),@dt_Lottable04,112)  ' +   
                                       ' AND CONVERT(CHAR(10),ISNULL(Lotattribute.Lottable05,''19000101''),112) =  CONVERT(CHAR(10),@dt_RecvDate,112)  ' +   
                                       ' ORDER BY PickDetail.PickDetailKey '

              SET @c_ExecArguments = N'   @as_LoadKey          NVARCHAR(20)'  
                                     +' , @c_Pickzone          NVARCHAR(10)' 
                                     +' , @c_Sku               NVARCHAR(20)' 
                                     +' , @c_Loc               NVARCHAR(10)' 
                                     +' , @c_ID                NVARCHAR(10)' 
                                     +' , @c_Lottable01        NVARCHAR(18)'
                                     +' , @c_Lottable02        NVARCHAR(18)'
                                     +' , @dt_Lottable04       DATETIME' 
                                     +' , @dt_RecvDate         DATETIME' 
              
              
               EXEC sp_ExecuteSql     @c_ExecStatement     
                                    , @c_ExecArguments    
                                    , @as_LoadKey  
                                    , @c_Pickzone  
                                    , @c_Sku 
                                    , @c_Loc
                                    , @c_ID 
                                    , @c_Lottable01 
                                    , @c_Lottable02
                                    , @dt_Lottable04
                                    , @dt_RecvDate
                                                 
              
              -- EXEC(@c_ExecStatement)
               OPEN C_PickDetailKey

               FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_orderkey, @c_OrderLineNumber

               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey)
                  BEGIN
                     INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)
                     VALUES (@c_PickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @as_LoadKey)

                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @n_err = 63503
                        SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert RefKeyLookup Failed. (nspConsoPickList42)'
                        GOTO FAILURE
                     END
                  END

                  FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_orderkey, @c_OrderLineNumber
               END
               CLOSE C_PickDetailKey
               DEALLOCATE C_PickDetailKey
            END

            UPDATE #TEMP_PICK
               SET PickSlipNo = @c_PickSlipNo
            WHERE LoadKey = @as_LoadKey
            AND   SKUGRP = @c_SKUGRP
            AND   Putawayzone = @c_Pickzone  
            AND   Sku = @c_Sku  
            AND   Loc = @c_Loc  
            AND   ID = @c_ID  
            AND   Lottable01 = @c_Lottable01  
            AND   Lottable02 = @c_Lottable02  
            AND   Lottable04 = @dt_Lottable04  
            AND   RecvDate   = @dt_RecvDate
            AND   (PickSlipNo IS NULL OR PickSlipNo = '')

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 63504
               SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update #Temp_Pick Failed. (nspConsoPickList42)'
               GOTO FAILURE
            END

            SET @c_PrevLoadKey = @as_LoadKey
            SET @c_PrevSKUGRP = @c_SKUGRP
            SET @c_PrevPickzone = @c_Pickzone  

            FETCH NEXT FROM C_Loadkey_LocTypeDesc INTO @as_LoadKey, @c_SKUGRP,
                                                       @c_Pickzone, @c_sku, @c_loc, @c_id, @c_lottable01, @c_lottable02, @dt_lottable04  
                                                      ,@c_LogicalLoc,@dt_RecvDate,@c_SSUSR3
                                                      ,@c_NOSPLITBYLINECNTZONE  
         END -- while 1

         CLOSE C_Loadkey_LocTypeDesc
         DEALLOCATE C_Loadkey_LocTypeDesc
         GOTO SUCCESS
      END --@n_continue = 1 or @n_continue = 2

 FAILURE:
     DELETE FROM #TEMP_PICK
     IF CURSOR_STATUS('LOCAL' , 'C_Loadkey_LocTypeDesc') in (0 , 1)
     BEGIN
        CLOSE C_Loadkey_LocTypeDesc
        DEALLOCATE C_Loadkey_LocTypeDesc
     END

     IF CURSOR_STATUS('GLOBAL' , 'C_PickDetailKey') in (0 , 1)
     BEGIN
        CLOSE C_PickDetailKey
        DEALLOCATE C_PickDetailKey
     END
     

 SUCCESS:
      SELECT * FROM #TEMP_PICK ORDER BY Pickslipno
      DROP Table #TEMP_PICK

   END -- @n_continue = 1 or 2

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspConsoPickList42'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END /* main procedure */


GO