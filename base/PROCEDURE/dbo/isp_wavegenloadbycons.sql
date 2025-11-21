SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_WaveGenLoadByCons                              */
/* Creation Date:  01-Dec-2010                                          */
/* Copyright: IDS                                                       */
/* Written by:  NJOW                                                    */
/*                                                                      */
/* Purpose:  Create load plan by wave by consignee                      */
/*                                                                      */
/* Input Parameters:  @c_WaveKey  - (WaveKey)                           */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  RMC Generate Load Plan By Consignee                      */
/*                                                                      */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: V2                                                          */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver  Purposes                                   */
/* 2016-11-16  Wan01    1.1  Close Cursor                               */
/* 28-Jan-2019 TLTING_ext 1.2  enlarge externorderkey field length      */
/* 01-Sep-2023 SPChin   1.3  JSM-169349 - Extend The Length Of C_Company*/ 
/* 02-JUL-2024 Wan02    1.4  EUR PROD - NLD - Cannot Gen Loadplan due to*/ 
/*                           C_Company NULL Value                       */
/* 02-JUL-2024 Wan03    1.5  EUR PROD - NLD - Cannot Gen Loadplan due to*/ 
/*                           C_Company NULL Value - fix2                */
/************************************************************************/

CREATE   PROCEDURE isp_WaveGenLoadByCons
   @c_WaveKey NVARCHAR(10),
   @b_Success int OUTPUT, 
   @n_err     int OUTPUT, 
   @c_errmsg  NVARCHAR(250) OUTPUT 
AS
BEGIN

   SET NOCOUNT ON       -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE 
      @c_ConsigneeKey      NVARCHAR( 15),
      @c_Priority          NVARCHAR( 10),
      @c_C_Company         NVARCHAR( 100),   --JSM-169349
      @c_OrderKey          NVARCHAR( 10),
      @c_Facility          NVARCHAR( 5),
      @c_ExternOrderKey    NVARCHAR( 50),  --tlting_ext
      @c_StorerKey         NVARCHAR( 15),
      @c_Route             NVARCHAR( 10),
      @c_debug             NVARCHAR( 1),
      @c_loadkey           NVARCHAR( 10),
      @n_continue          INT,
      @n_StartTranCnt      INT,
      @d_OrderDate         DATETIME,
      @d_Delivery_Date     DATETIME, 
      @c_OrderType         NVARCHAR( 10),
      @c_Door              NVARCHAR( 10),
      @c_DeliveryPlace     NVARCHAR( 30),
      @c_OrderStatus       NVARCHAR( 10),
      @n_loadcount         INT

   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1, @n_loadcount = 0

   IF NOT EXISTS(SELECT 1 FROM WaveDetail WITH (NOLOCK) 
                 WHERE WaveKey = @c_WaveKey)
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 63501
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Orders being populated into WaveDetail. (isp_WaveGenLoadByCons)"
   END
   
   BEGIN TRAN
      
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN    
      DECLARE cur_LPGroup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT O.ConsigneeKey, ISNULL(O.C_Company, ''), O.Storerkey
      FROM Orders O WITH (NOLOCK)
      JOIN WaveDetail WD WITH (NOLOCK) ON (O.OrderKey = WD.OrderKey)
      WHERE WD.WaveKey = @c_WaveKey
      AND ISNULL(O.Loadkey,'') = ''
      AND O.Status NOT IN ('0','9','CANC')
      GROUP BY O.Storerkey, O.ConsigneeKey, ISNULL(O.C_Company, '')                 --(Wan03)
      ORDER BY O.Storerkey, O.ConsigneeKey, ISNULL(O.C_Company, '')                 --(Wan03)

      OPEN cur_LPGroup
      FETCH NEXT FROM cur_LPGroup INTO @c_ConsigneeKey, @c_C_Company, @c_Storerkey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SELECT @b_success = 0
         EXECUTE nspg_GetKey
            'LOADKEY',
            10,
            @c_loadkey     OUTPUT,
            @b_success     OUTPUT,
            @n_err         OUTPUT,
            @c_errmsg      OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            GOTO RETURN_SP
         END

         SELECT TOP 1 @c_Facility = Facility                                      --(Wan03)
         FROM Orders WITH (NOLOCK) 
         WHERE  ConsigneeKey = @c_Consigneekey
            AND ISNULL(C_Company, '') = @c_C_Company                              --(Wan03)
            AND Userdefine09 = @c_WaveKey
            AND Storerkey = @c_StorerKey
            AND Status NOT IN ('0','9','CANC')
            AND ISNULL(Loadkey,'') = ''
         ORDER BY Orderkey                                                       --(Wan03)

         -- Create loadplan        
         INSERT INTO LoadPlan (LoadKey, Facility)
         VALUES (@c_loadkey, @c_Facility)

         SELECT @n_err = @@ERROR

         IF @n_err <> 0 
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63502
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into LOADPLAN Failed. (isp_WaveGenLoadByCons)"
            GOTO RETURN_SP
         END
         
         SELECT @n_loadcount = @n_loadcount + 1

         -- Create loadplan detail
         DECLARE cur_loadpland CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT O.OrderKey, O.ExternOrderKey
         FROM Orders O WITH (NOLOCK) 
         JOIN WaveDetail WD WITH (NOLOCK) ON (O.OrderKey = WD.OrderKey)
         WHERE  O.ConsigneeKey = @c_Consigneekey
            AND ISNULL(O.C_Company,'') = @c_C_Company                               --Wan02
            AND O.StorerKey = @c_StorerKey
            AND WD.WaveKey = @c_WaveKey
            AND O.Status NOT IN ('0','9','CANC')
            AND ISNULL(O.Loadkey,'') = ''
         ORDER BY O.OrderKey, O.ExternOrderKey

         OPEN cur_loadpland
         FETCH NEXT FROM cur_loadpland INTO @c_OrderKey, @c_ExternOrderKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF (SELECT COUNT(1) FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @c_OrderKey) = 0
            BEGIN
               SELECT @d_OrderDate = OrderDate, 
                      @d_Delivery_Date = DeliveryDate, 
                      @c_OrderType = Type,
                      @c_Door = Door,
                      @c_Route = Route,
                      @c_DeliveryPlace = DeliveryPlace,
                      @c_OrderStatus = Status,
                      @c_priority = Priority
               FROM Orders WITH (NOLOCK)
               WHERE OrderKey = @c_OrderKey  
                  
               EXEC isp_InsertLoadplanDetail 
                  @cLoadKey          = @c_LoadKey,
                  @cFacility         = @c_Facility,            
                  @cOrderKey         = @c_OrderKey,           
                  @cConsigneeKey     = @c_Consigneekey,
                  @cPrioriry         = @c_Priority,  
                  @dOrderDate        = @d_OrderDate,
                  @dDelivery_Date    = @d_Delivery_Date,    
                  @cOrderType        = @c_OrderType,   
                  @cDoor             = @c_Door,            
                  @cRoute            = @c_Route,                        
                  @cDeliveryPlace    = @c_DeliveryPlace,
                  @nStdGrossWgt      = 0,      
                  @nStdCube          = 0,         
                  @cExternOrderKey   = @c_ExternOrderKey,   
                  @cCustomerName     = @c_C_Company,
                  @nTotOrderLines    = 0,    
                  @nNoOfCartons      = 0,
                  @cOrderStatus      = '0', 
                  @b_Success         = @b_Success OUTPUT, 
                  @n_err             = @n_err     OUTPUT,
                  @c_errmsg          = @c_errmsg  OUTPUT               
   
               SELECT @n_err = @@ERROR
   
               IF @n_err <> 0 
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 63503
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into LOADPLANDETAIL Failed. (isp_WaveGenLoadByCons)"
                  GOTO RETURN_SP
               END
            END

            FETCH NEXT FROM cur_loadpland INTO @c_OrderKey, @c_ExternOrderKey
         END
         CLOSE cur_loadpland
         DEALLOCATE cur_loadpland

         FETCH NEXT FROM cur_LPGroup INTO @c_ConsigneeKey, @c_C_Company, @c_Storerkey
      END
      CLOSE cur_LPGroup
      DEALLOCATE cur_LPGroup
   END         
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @n_loadcount > 0
         SELECT @c_errmsg = RTRIM(CAST(@n_loadcount AS CHAR)) + ' Load Plan Generated'
      ELSE
         SELECT @c_errmsg = 'No Load Plan Generated'      
   END
   
END

RETURN_SP:

--(Wan01) - START
IF CURSOR_STATUS( 'LOCAL', 'CUR_LPGRoup') in (0 , 1)  
BEGIN
    CLOSE CUR_LPGRoup
    DEALLOCATE CUR_LPGRoup
END

IF CURSOR_STATUS( 'LOCAL', 'cur_loadpland') in (0 , 1)  
BEGIN
    CLOSE cur_loadpland
    DEALLOCATE cur_loadpland
END
--(Wan01) - END


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
   execute nsp_logerror @n_err, @c_errmsg, 'isp_WaveGenLoadByCons'
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

GO