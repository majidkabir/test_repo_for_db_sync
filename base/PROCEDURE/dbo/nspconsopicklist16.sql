SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  nspConsoPickList16                        		   */
/* Creation Date: 2008-03-25                            			    		*/
/* Copyright: IDS                                                       */
/* Written by: June                                       			    	*/
/*                                                                      */
/* Purpose:  Consolidated Pickslip for IDSTH	(SOS101777)						*/
/*                                                                      */
/* Input Parameters:  @c_loadkey  - Loadkey 										*/
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_consolidated_pick16_4       			*/
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                       							*/
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nspConsoPickList16] (
	@c_LoadKey NVARCHAR(10)
)
AS
BEGIN
	SET CONCAT_NULL_YIELDS_NULL OFF	
	SET NOCOUNT ON

	 DECLARE @c_FirstTime	  NVARCHAR(1),
			 	@c_PrintedFlag   NVARCHAR(1),
			 	@n_err           int,
	         @n_continue      int,
	         @c_PickHeaderKey NVARCHAR(10),
	         @b_success       int,
	         @c_errmsg        NVARCHAR(255),
	         @n_StartTranCnt  int 

	SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1
	-- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order
	
   BEGIN TRAN

	SELECT @c_PickHeaderKey = ''
	SELECT @c_PickHeaderKey = PickHeaderKey 
	FROM  PickHeader WITH (NOLOCK) 
	WHERE ExternOrderKey = @c_LoadKey
	AND   Zone = '7'

	IF RTRIM(@c_PickHeaderKey) IS NOT NULL AND RTRIM(@c_PickHeaderKey) <> '' 
	BEGIN
	   SELECT @c_FirstTime = 'N'
	   SELECT @c_PrintedFlag = 'Y'
	END
	ELSE
	BEGIN
	   SELECT @c_FirstTime = 'Y'
	   SELECT @c_PrintedFlag = 'N'
	END -- Record Not Exists

	-- Uses PickType as a Printed Flag
	IF @n_continue = 1 or @n_continue = 2
	BEGIN
	   IF @c_FirstTime = 'Y'
	   BEGIN
	      SELECT @c_PickHeaderKey = SPACE(10)	
	      SELECT @b_success = 0
	      
	      EXECUTE nspg_GetKey
	        'PICKSLIP',
	        9,   
	        @c_PickHeaderKey    OUTPUT,
	        @b_success   	 OUTPUT,
	        @n_err       	 OUTPUT,
	        @c_errmsg    	 OUTPUT
	
			IF @b_success <> 1
	      BEGIN
	         SELECT @n_continue = 3
            GOTO EXIT_SP 
 	      END

	      IF @n_continue = 1 or @n_continue = 2
	      BEGIN
	         SELECT @c_PickHeaderKey = 'P' + @c_PickHeaderKey
	         INSERT INTO PICKHEADER (PickHeaderKey,  ExternOrderKey, PickType, Zone, TrafficCop)
	                         VALUES (@c_PickHeaderKey, @c_LoadKey,      '0',  '7', '')
			END
		
			-- Do Auto Scan-in when only 1 storer found and configkey is setup
			IF @n_continue = 1 or @n_continue = 2
			BEGIN
				DECLARE @nCnt	int,
						  @cStorerKey NVARCHAR(15)
				
				IF ( SELECT COUNT(DISTINCT StorerKey) FROM ORDERS WITH (NOLOCK), LOADPLANDETAIL WITH (NOLOCK)
					  WHERE LOADPLANDETAIL.OrderKey = ORDERS.OrderKey AND	LOADPLANDETAIL.LoadKey = @c_LoadKey ) = 1
				BEGIN 
					-- Only 1 storer found
					SET @cStorerKey = ''
					SELECT @cStorerKey = (SELECT DISTINCT StorerKey 
												 FROM   ORDERS WITH (NOLOCK), LOADPLANDETAIL WITH (NOLOCK)
												 WHERE  LOADPLANDETAIL.OrderKey = ORDERS.OrderKey 
												 AND	  LOADPLANDETAIL.LoadKey = @c_LoadKey )
				
					IF EXISTS (SELECT 1 FROM STORERCONFIG WITH (NOLOCK) WHERE CONFIGKEY = 'AUTOSCANIN' AND
								  SValue = '1' AND StorerKey = @cStorerKey)
					BEGIN 
						-- Configkey is setup
			         IF NOT Exists(SELECT 1 FROM PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @c_PickHeaderKey)
			         BEGIN
			            INSERT INTO PickingInfo  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
			            VALUES (@c_PickHeaderKey, GetDate(), sUser_sName(), NULL)    
				      END
					END -- Configkey is setup
				END -- Only 1 storer found
			END			

		END  -- @c_FirstTime = 'Y'
	END -- IF @n_continue = 1 or @n_continue = 2

	IF @n_continue = 1 or @n_continue = 2
	BEGIN
	  SELECT LoadPlanDetail.LoadKey,   
	      PICKHEADER.PickHeaderKey PickSlipNO,
	      ISNULL(LoadPlan.Route, '') Route,  
	      LoadPlan.AddDate,   
	      PICKDETAIL.Loc,   
	      PICKDETAIL.Sku,   
	      PICKDETAIL.Qty,		 		  
	      SKU.DESCR SKU_DESCR,   
	      PACK.CaseCnt,  
	      PACK.PackKey,
	      ISNULL(LoadPlan.CarrierKey, '') CarrierKey,
	      PICKDETAIL.ID AS Pallet_ID,
	      LOTATTRIBUTE.Lottable01, 
	      LOTATTRIBUTE.Lottable02, 
	      LOTATTRIBUTE.Lottable03, 
	      LOTATTRIBUTE.Lottable04, 
	      LOTATTRIBUTE.Lottable05,
			PACK.Pallet,
		   LoadPlan.Delivery_Zone
	  FROM LoadPlanDetail WITH (NOLOCK)
     JOIN ORDERDETAIL WITH (NOLOCK) ON ( LoadPlanDetail.LoadKey = ORDERDETAIL.LoadKey AND 
                                    LoadPlanDetail.OrderKey = ORDERDETAIL.OrderKey)  
	  JOIN ORDERS WITH (NOLOCK) ON ( ORDERDETAIL.OrderKey = ORDERS.OrderKey )
	  JOIN PICKDETAIL WITH (NOLOCK) ON ( ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey ) AND   
	                 ( ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber )   
	  JOIN SKU WITH (NOLOCK) ON  ( SKU.StorerKey = PICKDETAIL.Storerkey ) AND  
	                        ( SKU.Sku = PICKDETAIL.Sku )
	  JOIN LoadPlan WITH (NOLOCK) ON ( LoadPlanDetail.LoadKey = LoadPlan.LoadKey ) 
	  JOIN PACK WITH (NOLOCK) ON ( PACK.PackKey = SKU.PACKKey ) 
	  JOIN PICKHEADER WITH (NOLOCK) ON ( PICKHEADER.ExternOrderKey = LoadPlan.LoadKey ) AND
	                        ( PICKHEADER.Zone = '7' )
	  JOIN LOTATTRIBUTE WITH (NOLOCK) ON ( LOTATTRIBUTE.Lot = PICKDETAIL.Lot )
	  WHERE ( LoadPlanDetail.LoadKey = @c_LoadKey )
	END

   EXIT_SP:

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
     EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspConsoPickList16'    
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
     RETURN    
   END    
   ELSE    
   BEGIN    
      /* Error Did Not Occur , Return Normally */    
      SELECT @b_success = 1    
      WHILE @@TRANCOUNT > @n_StartTranCnt     
      BEGIN    
         COMMIT TRAN    
      END              
      RETURN    
 END    
   /* End Return Statement */ 

END /* main procedure */

GO