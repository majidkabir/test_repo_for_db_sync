SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nspDynamicPickCode01                               */
/* Creation Date:  18-Apr-2003                                          */
/* Copyright: IDS                                                       */
/* Written by:  James                                                   */
/*                                                                      */
/* Purpose:  Auto create load plan for NIKE Dynamic Pick                */
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
/* Called By:  RMC Generate Dynamic Pick slip                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 22-Jul-2008  SHONG     Move actions to Wave Dyanamic Allocation:     */
/*                        1) Insert PackDet 2) Update PSpNo to PickDet  */
/* 26-Jul-2008  James     Remove group by consigneekey where            */
/*                        substring(consigneekey, 1, 4) = '0008'. One   */
/*                        pickslip/loadkey per consignee                */
/* 11-Aug-2008  James     Add checking to prevent generate twice        */
/*                        picklist based on LoadKey                     */
/************************************************************************/

CREATE PROC [dbo].[nspDynamicPickCode01] 
   @c_WaveKey NVARCHAR(10),
   @b_Success int OUTPUT, 
   @n_err     int OUTPUT, 
   @c_errmsg  NVARCHAR(250) OUTPUT 
AS
BEGIN

   SET NOCOUNT ON			-- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    


   DECLARE 
      @c_ConsigneeKey      NVARCHAR( 15),
      @c_Priority          NVARCHAR( 10),
      @c_C_Company         NVARCHAR( 45),
      @c_PickHeaderKey     NVARCHAR( 10),
      @c_OrderKey          NVARCHAR( 10),
      @c_Facility          NVARCHAR( 5),
      @c_ExternOrderKey    NVARCHAR( 30),
      @c_StorerKey         NVARCHAR( 15),
      @c_PickDetailKey     NVARCHAR( 10),
      @c_labelno           NVARCHAR( 20),
      @c_UCCNo             NVARCHAR( 20),
      @c_SKU               NVARCHAR( 20),
      @c_LabelLine         NVARCHAR( 5),
      @c_LineNo            NVARCHAR( 5),
      @c_Route             NVARCHAR( 10),
      @c_debug             NVARCHAR( 1),
      @c_loadkey           NVARCHAR( 10),
		@n_continue          INT,
		@n_StartTranCnt      INT,
      @n_LineNo            INT,
      @n_CartonNo          INT,
      @nQTY                INT,
      @d_OrderDate         DATETIME,
      @d_Delivery_Date     DATETIME, 
      @c_OrderType         NVARCHAR( 10),
      @c_Door              NVARCHAR( 10),
      @c_DeliveryPlace     NVARCHAR( 30),
      @c_OrderStatus       NVARCHAR( 10),
      @nStdGrossWgt        INT ,
      @nStdCube            INT ,
      @nTotOrderLines      INT ,
      @nNoOfCartons        INT

	SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1

   IF NOT EXISTS(SELECT 1 FROM WaveDetail WITH (NOLOCK) 
                 WHERE WaveKey = @c_WaveKey)
	BEGIN
		SELECT @n_continue = 3
		SELECT @n_err = 63501
		SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Orders being populated into WaveDetail. (nspDynamicPickCode01)"
	END

   IF NOT EXISTS (SELECT 1 FROM ORDERS O WITH (NOLOCK)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON O.ORDERKEY = OD.ORDERKEY
      WHERE O.USERDEFINE09 = @c_WaveKey
         AND (O.LOADKEY = '' OR O.LOADKEY IS NULL))
	BEGIN
		SELECT @n_continue = 3
		SELECT @n_err = 63502
		SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Cannot generate again the Pick List. All Orders being Waved. (nspDynamicPickCode01)"
	END
	
	BEGIN TRAN
		
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN 	
      DECLARE cur_Pickslip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT O.ConsigneeKey, O.Priority, O.C_Company
      FROM Orders O WITH (NOLOCK)
      JOIN WaveDetail WD WITH (NOLOCK, INDEX(IX_WAVEDETAIL_OrderKey)) ON (O.OrderKey = WD.OrderKey)
      WHERE WaveKey = @c_WaveKey
      	AND SUBSTRING(O.ConsigneeKey, 1, 4) <> '0008'      
      GROUP BY O.ConsigneeKey, O.Priority, O.C_Company, O.C_Address2, O.C_Address3

      OPEN cur_Pickslip
      FETCH NEXT FROM cur_Pickslip INTO @c_ConsigneeKey, @c_Priority, @c_C_Company
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @n_CartonNo = 0  --Reset carton no

		   SELECT @b_success = 0
		   EXECUTE nspg_GetKey
			   'PICKSLIP',
			   9,   
			   @c_PickHeaderKey   OUTPUT,
			   @b_success   	    OUTPUT,
			   @n_err 	          OUTPUT,
			   @c_errmsg    	    OUTPUT

		   IF @b_success <> 1
		   BEGIN
			   SELECT @n_continue = 3
		   END

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
		   END

         IF @c_debug = '1'
         BEGIN
            SELECT 'PICKSLIP', @c_PickHeaderKey
            SELECT 'LOADKEY', @c_loadkey
         END         

         -- create pickheader
		   IF @n_continue = 1 or @n_continue = 2
		   BEGIN
			   SELECT @c_PickHeaderKey = 'P' + @c_PickHeaderKey

			   INSERT INTO PICKHEADER (PickHeaderKey,  ExternOrderKey, PickType, Zone)
			   VALUES (@c_PickHeaderKey, @c_loadkey, '1', '7')
             
			   SELECT @n_err = @@ERROR
   	
			   IF @n_err <> 0 
			   BEGIN
				   SELECT @n_continue = 3
				   SELECT @n_err = 63501
				   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into PICKHEADER Failed. (nspDynamicPickCode01)"
               GOTO RETURN_SP
			   END
		   END -- @n_continue = 1 or @n_continue = 2

         SELECT 
            @c_Facility = Facility, 
            @c_StorerKey = StorerKey,
            @c_Route = Route
         FROM Orders WITH (NOLOCK) 
         WHERE  ConsigneeKey = @c_Consigneekey
            AND Priority = @c_Priority
            AND C_Company = @c_C_Company
            AND Userdefine09 = @c_WaveKey

         -- Create loadplan
         INSERT INTO LoadPlan (LoadKey, Facility)
         VALUES
         (@c_loadkey, @c_Facility)

		   SELECT @n_err = @@ERROR

		   IF @n_err <> 0 
		   BEGIN
			   SELECT @n_continue = 3
			   SELECT @n_err = 63501
			   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into LOADPLAN Failed. (nspDynamicPickCode01)"
            GOTO RETURN_SP
		   END

         -- Create PackHeader
		   INSERT PackHeader (PickSlipNo, StorerKey, OrderKey, OrderRefNo, ConsigneeKey, Loadkey, Route)
         VALUES
         (@c_PickHeaderKey, @c_StorerKey, '', '', @c_ConsigneeKey, @c_LoadKey, @c_Route)
         
         SELECT @n_err = @@ERROR

         IF @n_err <> 0 
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63501
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into PACKHEADER Failed. (nspDynamicPickCode01)"
            GOTO RETURN_SP
         END

         -- Create loadplan detail
         DECLARE cur_loadpland CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT O.OrderKey, O.ExternOrderKey, O.Route
         FROM Orders O WITH (NOLOCK) 
         JOIN WaveDetail WD WITH (NOLOCK) ON (O.OrderKey = WD.OrderKey)
         WHERE  O.ConsigneeKey = @c_Consigneekey
            AND O.Priority = @c_Priority
            AND O.C_Company = @c_C_Company
            AND WD.WaveKey = @c_WaveKey
         GROUP BY O.OrderKey, O.ExternOrderKey, O.Route

         OPEN cur_loadpland
         FETCH NEXT FROM cur_loadpland INTO @c_OrderKey, @c_ExternOrderKey, @c_Route
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM LoadPlanDetail WITH (NOLOCK) 
               WHERE OrderKey = @c_OrderKey)
            BEGIN
               /*
               SELECT @n_LineNo = ISNULL(MAX(LoadLineNumber),0) 
               FROM  LOADPLANDETAIL WITH (NOLOCK) 
               WHERE LoadKey = @c_LoadKey

	            SELECT @c_LineNo = dbo.fnc_LTRIM(dbo.fnc_RTRIM(CONVERT(char(5), @n_LineNo + 1))) -- New line number
	            SELECT @c_LineNo = REPLICATE('0', 5 - LEN(@c_LineNo)) + @c_LineNo

               INSERT INTO LOADPLANDETAIL 
               (LoadKey, LoadLineNumber, OrderKey, Consigneekey, ExternOrderKey, Status, CustomerName) 
               VALUES
	            (@c_LoadKey, @c_LineNo, @c_OrderKey, @c_Consigneekey, @c_ExternOrderKey, '0', @c_C_Company)

               
		         SELECT @n_err = @@ERROR

		         IF @n_err <> 0 
		         BEGIN
			         SELECT @n_continue = 3
			         SELECT @n_err = 63501
			         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into LOADPLANDETAIL Failed. (nspDynamicPickCode01)"
                  GOTO RETURN_SP
		         END
		         */
		         SELECT 
                  @d_OrderDate = OrderDate, 
                  @d_Delivery_Date = DeliveryDate, 
                  @c_OrderType = Type,
                  @c_Door = Door,
                  @c_Route = Route,
                  @c_DeliveryPlace = DeliveryPlace,
                  @c_OrderStatus = Status
               FROM Orders WITH (NOLOCK)
               WHERE OrderKey = @c_OrderKey  
                  AND StorerKey = @c_StorerKey
                  
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
                  SELECT @n_err = 63501
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into LOADPLANDETAIL Failed. (nspDynamicPickCode01)"
                  GOTO RETURN_SP
               END
            END

            -- Commented By SHONG on 22nd Jul 2008
            -- Move this Statement into Dynamic Allocation
            -- Create packdetail
            /* 
            DECLARE cur_packd CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PickDetailKey, SKU, QTY
            FROM PickDetail WITH (NOLOCK) 
            WHERE  StorerKey = @c_StorerKey
               AND OrderKey  = @c_OrderKey
               AND Status    < '5'
            ORDER BY SKU
            OPEN cur_packd
     FETCH NEXT FROM cur_packd INTO @c_PickDetailKey, @c_SKU, @nQTY
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Get Carton No
               SET @n_CartonNo = @n_CartonNo + 1

               -- Get Label No
               SET @c_labelno = ''
	            EXECUTE nsp_genlabelno
		            @c_OrderKey,
		            @c_StorerKey  ,
		            @c_Labelno     = @c_Labelno OUTPUT,
		            @n_Cartonno		= @n_Cartonno OUTPUT,
		            @c_button		= '',
		            @b_success     = @b_success OUTPUT,
		            @n_err         = @n_err     OUTPUT,
		            @c_errmsg      = @c_errmsg  OUTPUT

				   IF @b_success <> 1
				   BEGIN
					   SELECT @n_continue = 3
				   END
				   
               IF @c_debug = '1'
               BEGIN
                  SELECT '@c_Labelno', @c_Labelno
               END

               IF NOT EXISTS (SELECT 1 FROM PackDetail WITH (NOLOCK) 
                  WHERE PickSlipNo = @c_PickHeaderKey
                     AND LabelNo = @c_LabelNo)
               BEGIN
                  -- Get Labelline No
                  SELECT @c_LabelLine = RIGHT('0000' + dbo.fnc_RTRIM(CAST(ISNULL(CAST(MAX(LabelLine) AS INT), 0) + 1 AS NVARCHAR(5))), 5)
                  FROM   PackDetail WITH (NOLOCK)
                  WHERE  PickSlipNo = @c_PickHeaderKey 
                     AND    CartonNo   = @n_CartonNo 

                  -- Get UCC No
                  SELECT @c_UCCNo = UCCNo 
                  FROM UCC WITH (NOLOCK) 
                  WHERE StorerKey = @c_StorerKey
                     AND PickDetailKey = @c_PickDetailKey
                     AND SKU = @c_SKU

                  INSERT INTO PackDetail 
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, RefNo)
                  VALUES
                  (@c_PickHeaderKey, @n_CartonNo, @c_LabelNo, @c_LabelLine, @c_StorerKey, @c_SKU, @nQty, @c_UCCNo)
                  
		            SELECT @n_err = @@ERROR

		            IF @n_err <> 0 
		            BEGIN
			            SELECT @n_continue = 3
			            SELECT @n_err = 63501
			            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into LOADPLANDETAIL Failed. (nspDynamicPickCode01)"
                     GOTO RETURN_SP
		            END
		            
		            UPDATE PickDetail WITH (ROWLOCK) SET
		            	PickSlipNo = @c_PickHeaderKey,
							TrafficCop = NULL
						WHERE PickDetailKey = @c_PickDetailKey
						
						SELECT @n_err = @@ERROR

		            IF @n_err <> 0 
		            BEGIN
			            SELECT @n_continue = 3
			            SELECT @n_err = 63501
			            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update PickDetail with pick slip no Failed. (nspDynamicPickCode01)"
                     GOTO RETURN_SP
		            END
               END
            FETCH NEXT FROM cur_packd INTO @c_PickDetailKey, @c_SKU, @nQTY
            END
            close cur_packd
            DEALLOCATE cur_packd
            */

            FETCH NEXT FROM cur_loadpland INTO @c_OrderKey, @c_ExternOrderKey, @c_Route
         END
         CLOSE cur_loadpland
         DEALLOCATE cur_loadpland

         FETCH NEXT FROM cur_Pickslip INTO @c_ConsigneeKey, @c_Priority, @c_C_Company
      END
      CLOSE cur_Pickslip
      DEALLOCATE cur_Pickslip
   END   -- End for n_continue = 1 or n_continue = 2
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE cur_Pickslip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT O.ConsigneeKey, O.Priority, O.C_Company, O.OrderKey, O.ExternOrderKey, O.Route
      FROM Orders O WITH (NOLOCK)
      JOIN WaveDetail WD WITH (NOLOCK, INDEX(IX_WAVEDETAIL_OrderKey)) ON (O.OrderKey = WD.OrderKey)
      WHERE WaveKey = @c_WaveKey
      	AND SUBSTRING(O.ConsigneeKey, 1, 4) = '0008'
      ORDER BY O.ORDERKEY

      OPEN cur_Pickslip
      FETCH NEXT FROM cur_Pickslip INTO @c_ConsigneeKey, @c_Priority, @c_C_Company, 
         @c_OrderKey, @c_ExternOrderKey, @c_Route
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @n_CartonNo = 0  --Reset carton no

         SELECT @b_success = 0
         EXECUTE nspg_GetKey
            'PICKSLIP',
            9,   
            @c_PickHeaderKey   OUTPUT,
            @b_success   	    OUTPUT,
            @n_err 	          OUTPUT,
            @c_errmsg    	    OUTPUT
         
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
         END

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
		   END

         IF @c_debug = '1'
         BEGIN
            SELECT 'PICKSLIP', @c_PickHeaderKey
            SELECT 'LOADKEY', @c_loadkey
         END         

         -- create pickheader
		   IF @n_continue = 1 or @n_continue = 2
		   BEGIN
			   SELECT @c_PickHeaderKey = 'P' + @c_PickHeaderKey

			   INSERT INTO PICKHEADER (PickHeaderKey,  ExternOrderKey, PickType, Zone)
			   VALUES (@c_PickHeaderKey, @c_loadkey, '1', '7')
             
			   SELECT @n_err = @@ERROR
   	
			   IF @n_err <> 0 
			   BEGIN
				   SELECT @n_continue = 3
				   SELECT @n_err = 63501
				   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into PICKHEADER Failed. (nspDynamicPickCode01)"
               GOTO RETURN_SP
			   END
		   END -- @n_continue = 1 or @n_continue = 2

         SELECT 
            @c_Facility = Facility, 
            @c_StorerKey = StorerKey,
            @c_Route = Route
         FROM Orders WITH (NOLOCK) 
         WHERE  ConsigneeKey = @c_Consigneekey
            AND Priority = @c_Priority
            AND C_Company = @c_C_Company
            AND Userdefine09 = @c_WaveKey

         -- Create loadplan
         INSERT INTO LoadPlan (LoadKey, Facility)
         VALUES
         (@c_loadkey, @c_Facility)

		   SELECT @n_err = @@ERROR

		   IF @n_err <> 0 
		   BEGIN
			   SELECT @n_continue = 3
			   SELECT @n_err = 63501
			   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into LOADPLAN Failed. (nspDynamicPickCode01)"
            GOTO RETURN_SP
		   END

         -- Create PackHeader
		   INSERT PackHeader (PickSlipNo, StorerKey, OrderKey, OrderRefNo, ConsigneeKey, Loadkey, Route)
         VALUES
         (@c_PickHeaderKey, @c_StorerKey, '', '', @c_ConsigneeKey, @c_LoadKey, @c_Route)
         
         SELECT @n_err = @@ERROR

         IF @n_err <> 0 
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63501
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into PACKHEADER Failed. (nspDynamicPickCode01)"
            GOTO RETURN_SP
         END

         IF NOT EXISTS (SELECT 1 FROM LoadPlanDetail WITH (NOLOCK) 
            WHERE OrderKey = @c_OrderKey)
         BEGIN
            SELECT 
               @d_OrderDate = OrderDate, 
               @d_Delivery_Date = DeliveryDate, 
               @c_OrderType = Type,
               @c_Door = Door,
               @c_Route = Route,
               @c_DeliveryPlace = DeliveryPlace,
               @c_OrderStatus = Status
            FROM Orders WITH (NOLOCK)
            WHERE OrderKey = @c_OrderKey  
               AND StorerKey = @c_StorerKey

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
               SELECT @n_err = 63501
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into LOADPLANDETAIL Failed. (nspDynamicPickCode01)"
               GOTO RETURN_SP
            END		         
         END

            -- Commented By SHONG on 22nd Jul 2008
            -- Move this Statement into Dynamic Allocation
            -- Create packdetail
            /*
            DECLARE cur_packd CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PickDetailKey, SKU, QTY
            FROM PickDetail WITH (NOLOCK) 
            WHERE  StorerKey = @c_StorerKey
               AND OrderKey  = @c_OrderKey
               AND Status    < '5'
            ORDER BY SKU
            OPEN cur_packd
            FETCH NEXT FROM cur_packd INTO @c_PickDetailKey, @c_SKU, @nQTY
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Get Carton No
               SET @n_CartonNo = @n_CartonNo + 1

               -- Get Label No
               SET @c_labelno = ''
	            EXECUTE nsp_genlabelno
		            @c_OrderKey,
		            @c_StorerKey  ,
		            @c_Labelno     = @c_Labelno OUTPUT,
		            @n_Cartonno		= @n_Cartonno OUTPUT,
		            @c_button		= '',
		            @b_success     = @b_success OUTPUT,
		            @n_err         = @n_err     OUTPUT,
		            @c_errmsg      = @c_errmsg  OUTPUT

				   IF @b_success <> 1
				   BEGIN
					   SELECT @n_continue = 3
				   END
		   
               IF @c_debug = '1'
               BEGIN
                  SELECT '@c_Labelno', @c_Labelno
               END

               IF NOT EXISTS (SELECT 1 FROM PackDetail WITH (NOLOCK) 
                  WHERE PickSlipNo = @c_PickHeaderKey
                     AND LabelNo = @c_LabelNo)
               BEGIN
                  -- Get Labelline No
                  SELECT @c_LabelLine = RIGHT('0000' + dbo.fnc_RTRIM(CAST(ISNULL(CAST(MAX(LabelLine) AS INT), 0) + 1 AS NVARCHAR(5))), 5)
                  FROM   PackDetail WITH (NOLOCK)
                  WHERE  PickSlipNo = @c_PickHeaderKey 
                     AND    CartonNo   = @n_CartonNo 

                  -- Get UCC No
                  SELECT @c_UCCNo = UCCNo 
                  FROM UCC WITH (NOLOCK) 
                  WHERE StorerKey = @c_StorerKey
                     AND PickDetailKey = @c_PickDetailKey
                     AND SKU = @c_SKU

                  INSERT INTO PackDetail 
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, RefNo)
                  VALUES
                  (@c_PickHeaderKey, @n_CartonNo, @c_LabelNo, @c_LabelLine, @c_StorerKey, @c_SKU, @nQty, @c_UCCNo)
                  
		            SELECT @n_err = @@ERROR

		            IF @n_err <> 0 
		            BEGIN
			            SELECT @n_continue = 3
			            SELECT @n_err = 63501
			            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into LOADPLANDETAIL Failed. (nspDynamicPickCode01)"
                     GOTO RETURN_SP
		            END
		            
		            UPDATE PickDetail WITH (ROWLOCK) SET
		            	PickSlipNo = @c_PickHeaderKey,
							TrafficCop = NULL
						WHERE PickDetailKey = @c_PickDetailKey
						
						SELECT @n_err = @@ERROR

		            IF @n_err <> 0 
		            BEGIN
			            SELECT @n_continue = 3
			            SELECT @n_err = 63501
			            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update PickDetail with pick slip no Failed. (nspDynamicPickCode01)"
                     GOTO RETURN_SP
		            END
               END
            FETCH NEXT FROM cur_packd INTO @c_PickDetailKey, @c_SKU, @nQTY
            END
            close cur_packd
            DEALLOCATE cur_packd
            */
         FETCH NEXT FROM cur_Pickslip INTO @c_ConsigneeKey, @c_Priority, @c_C_Company, 
            @c_OrderKey, @c_ExternOrderKey, @c_Route
      END
      CLOSE cur_Pickslip
      DEALLOCATE cur_Pickslip
   END   -- End for n_continue = 1 or n_continue = 2
   
END

RETURN_SP:

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
	execute nsp_logerror @n_err, @c_errmsg, 'nspDynamicPickCode01'
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