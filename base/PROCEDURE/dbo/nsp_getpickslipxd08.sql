SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : nsp_GetPickSlipXD08 	                           		*/
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: Vanessa		                                             */
/*                                                                      */
/* Purpose: PickSlip Report                              					*/
/*                                                                      */
/* Called By: r_dw_print_pickxdorder08						                  */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author    Ver.    	Purposes                            */
/* 25-JAN-2017  JayLim   1.1  SQL2012 compatibility modification (Jay01)*/
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipXD08] (@c_refkey NVARCHAR(20), @c_type NVARCHAR(2)) 
AS
BEGIN
-- Type = P for ExternPOKey, L for LoadKey
   SET NOCOUNT ON			-- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF        

   DECLARE @c_pickheaderkey	   NVARCHAR(10),
         @c_New_PICKDETAILKey    NVARCHAR(10), 
	      @n_continue		         int,
	      @c_errmsg		         NVARCHAR(255),
	      @b_success		         int,
	      @n_err			         int,
	      @c_sku			         NVARCHAR(20), 
		   @c_firsttime	         NVARCHAR(1), 
		   @c_row			         NVARCHAR(10), 
		   @c_PrintedFlag	         NVARCHAR(1), 
         @c_BreakKey             NVARCHAR(100),            
         @c_Prev_BreakKey        NVARCHAR(100), 
		   @c_storerkey	         NVARCHAR(15), 
		   @c_recvby		         NVARCHAR(18), 
		   @n_rowid			         int, 
         @n_rowid1		         int, 
		   @n_starttcnt            int,
         @c_ConfigKey            NVARCHAR(30),
         @c_SValue               NVARCHAR(10),
         @c_ConsigneeKey         NVARCHAR(15),
         @d_DeliveryDate         Datetime,
         @c_BUSR5                NVARCHAR(30),
         @c_CLASS                NVARCHAR(10),
         @c_itemclass            NVARCHAR(10),
         @c_SKUGROUP             NVARCHAR(10),
         @c_Style                NVARCHAR(20),
         @c_Color                NVARCHAR(10),
         @c_Size                 NVARCHAR(5), 
         @c_Measurement          NVARCHAR(5),
         @c_PickslipNo			   NVARCHAR(10), 
         @c_CartonType           NVARCHAR(10), 
         @n_StdGrossWGT          float,          
         @n_STDCube              float,      
         @n_QtyPick              int,     
         @n_MaxWeight            float,     
         @n_MaxCube              float,            
         @n_CumWeight            float,      
         @n_CumCube              float,      
         @n_SplitQty             int,
         @n_CurQty               int, 
         @n_CapWeight            float,  
         @n_CapCube              float,
         @c_Remark               NVARCHAR(30),
         @c_DropID               NVARCHAR(10),
         @n_Capacity             float,
         @c_PICKDETAILKey        NVARCHAR(10),
         @b_break                NVARCHAR(1),   
         @c_debug                NVARCHAR(1),
         @b_newgroup             NVARCHAR(1),
         @b_getdropid            NVARCHAR(1),
         @n_rowid2               int,
         @n_casecnt              float,
         @n_innerpack            float,
         @n_pallet               float,
         @c_uom                  NVARCHAR(10)

   SET @c_debug = '0'  

	CREATE TABLE #TEMPPICKDETAIL (
         Rowid			      int IDENTITY(1,1),
			PickDetailKey	 NVARCHAR(18),
			OrderKey			 NVARCHAR(10), 
			OrderLineNumber NVARCHAR(5),  
			StorerKey		 NVARCHAR(15),  
			Sku				 NVARCHAR(20),  
			Qty					Int,		
			Lot				 NVARCHAR(10),  
			Loc				 NVARCHAR(10), 
			ID					 NVARCHAR(18), 
			Packkey			 NVARCHAR(10), 
			PickslipNo		 NVARCHAR(10) NULL, 
         UOM               NVARCHAR(10),
         DropID            NVARCHAR(10),
         ConsigneeKey      NVARCHAR(15), 
         C_Company         NVARCHAR(45) NULL, 
         Priority          NVARCHAR(10),
         DeliveryDate      Datetime,
         Capacity          NVARCHAR(10) NULL,
         Remark            NVARCHAR(30) NULL, 
			PrintedFlag		 NVARCHAR(1))
			
   CREATE TABLE #TEMPXDPARTIALPLT (
         Rowid			    int IDENTITY(1,1),
         DropId          NVARCHAR(10),
         ConsigneeKey    NVARCHAR(15),
         DeliveryDate    datetime,         
         Col1            NVARCHAR(30) Null,
         Col2            NVARCHAR(30) Null,
         Col3            NVARCHAR(30) Null,
         Col4            NVARCHAR(30) Null,
         Col5            NVARCHAR(30) Null,
         Col6            NVARCHAR(30) Null,
         Col7            NVARCHAR(30) Null, 
         Col8            NVARCHAR(30) Null,
         Col9            NVARCHAR(30) Null,
         Col10           NVARCHAR(30) Null,
         CumWeight       float,
         CumCube         float)
	   	   		   
   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT 
	SELECT @c_row = '0'

   BEGIN TRAN 
   --DELETE FROM XDPartialPlt WHERE deliverydate < CONVERT(DATETIME,CONVERT(char(10),GETDATE() - 3, 101))
   --use 100 days for testing only
   DELETE FROM XDPartialPlt WHERE deliverydate < CONVERT(DATETIME,CONVERT(char(10),GETDATE() - 100, 101))   
   IF @@ERROR = 0 
   BEGIN
      WHILE @@TRANCOUNT > 0 
         COMMIT TRAN 
   END -- @@ERROR = 0 	
   ELSE
   BEGIN 
      ROLLBACK TRAN 
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63300   
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
   END  -- @@ERROR <> 0 

   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, XD - CrossDock 
   IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK) 
             WHERE ExternOrderKey = @c_refkey 
             AND   Zone = 'XD')
   BEGIN
      SELECT @c_firsttime = 'N'
	
      IF EXISTS (SELECT 1 FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @c_refkey AND Zone = 'XD'
                 AND PickType = '0')
      BEGIN
         SELECT @c_PrintedFlag = 'N'
      END  -- PickType = '0'
      ELSE
      BEGIN
         SELECT @c_PrintedFlag = 'Y'
      END  -- PickType <> '0'

      -- Uses PickType as a Printed Flag
      BEGIN TRAN 

      UPDATE PickHeader
      SET PickType = '1',
          TrafficCop = NULL
      WHERE ExternOrderKey = @c_refkey 
      AND   Zone = 'XD'
      AND   PickType = '0'

      IF @@ERROR = 0 
      BEGIN
         WHILE @@TRANCOUNT > 0 
            COMMIT TRAN 
      END -- @@ERROR = 0 	
      ELSE
      BEGIN 
         ROLLBACK TRAN 
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63301   
   		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update PickHeader Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
      END  -- @@ERROR <> 0 

		SELECT @c_PrintedFlag = 'Y'
	END -- Record EXIST
	ELSE
   BEGIN
      SELECT @c_firsttime = 'Y'
      SELECT @c_PrintedFlag = 'N'
   END -- Record Not Exists

	IF (@n_continue = 1 or @n_continue=2)  
	BEGIN
      BEGIN TRAN 

		IF dbo.fnc_RTRIM(@c_type) = 'P' 
		BEGIN
			INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku, Qty, Lot, Loc, ID, Packkey, 
                                      PickSlipNo, UOM, DropID, ConsigneeKey, C_Company, Priority, DeliveryDate, PrintedFlag, Capacity, Remark)
			SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, PD.Lot, PD.Loc, PD.ID, PD.Packkey, 
                PD.PickSlipNo, PD.UOM, PD.DropID, OH.CONSIGNEEKEY, OH.C_COMPANY, OH.Priority, OH.DeliveryDate, @c_PrintedFlag, LEFT(PD.AltSku,3),SUBSTRING(PD.AltSku,4,3)
			  FROM ORDERDETAIL OD (NOLOCK), PICKDETAIL PD (NOLOCK), ORDERS OH (NOLOCK) 
			 WHERE PD.ORDERKEY = OD.ORDERKEY 
				AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER 
            AND OH.ORDERKEY = OD.ORDERKEY
				AND OD.EXTERNPOKEY = @c_refkey 
				AND PD.STATUS < '5'
			ORDER BY OH.CONSIGNEEKEY, OH.DeliveryDate, PD.UOM, PD.Pickdetailkey
      
         IF @@ERROR = 0 
         BEGIN
            WHILE @@TRANCOUNT > 0 
               COMMIT TRAN 
         END -- @@ERROR = 0 	
         ELSE
         BEGIN 
            ROLLBACK TRAN 
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63302   
   		   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         END  -- @@ERROR <> 0 

		END  -- dbo.fnc_RTRIM(@c_type) = 'P' 
		ELSE
		BEGIN
			INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku, Qty, Lot, Loc, ID, Packkey, 
                                      PickSlipNo, UOM, DropID, ConsigneeKey, C_Company, Priority, DeliveryDate, PrintedFlag, Capacity, Remark)
			SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, PD.Lot, PD.Loc, PD.ID, PD.Packkey, 
                PD.PickSlipNo, PD.UOM, PD.DropID, OH.CONSIGNEEKEY, OH.C_COMPANY, OH.Priority, OH.DeliveryDate, @c_PrintedFlag, LEFT(PD.AltSku,3), SUBSTRING(PD.AltSku,4,3)
			 FROM LOADPLANDETAIL LPD (NOLOCK), PICKDETAIL PD (NOLOCK), ORDERS OH (NOLOCK)
			 WHERE PD.ORDERKEY = LPD.ORDERKEY 
            AND OH.ORDERKEY = PD.ORDERKEY
				AND LPD.LOADKEY = @c_refkey 
				AND PD.STATUS < '5'
			ORDER BY OH.CONSIGNEEKEY, OH.DeliveryDate,PD.UOM, PD.Pickdetailkey

         IF @@ERROR = 0 
         BEGIN
            WHILE @@TRANCOUNT > 0 
               COMMIT TRAN 
         END -- @@ERROR = 0 	
         ELSE
         BEGIN 
            ROLLBACK TRAN 
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63303   
   		   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         END  -- @@ERROR <> 0 

		END  -- dbo.fnc_RTRIM(@c_type) <> 'P' 

      IF @c_debug = '1'      
      BEGIN      
	      SELECT *
	      FROM #TEMPPICKDETAIL 
      END

      SELECT @c_ConfigKey = StorerConfig.ConfigKey, 
             @c_SValue = StorerConfig.SValue 
      FROM #TEMPPICKDETAIL (NOLOCK)
      JOIN StorerConfig (NOLOCK) on ( StorerConfig.StorerKey = #TEMPPICKDETAIL.StorerKey ) 
                                     AND StorerConfig.ConfigKey = 'PID_CTZN'  

      IF @c_debug = '1'      
      BEGIN      
         SELECT '1. @c_ConfigKey=' + @c_ConfigKey + ' @c_SValue=' + @c_SValue
      END

      IF @c_ConfigKey = 'PID_CTZN' AND @c_SValue = '1'
      BEGIN 

         SELECT @c_ConfigKey = ''
         SELECT @c_SValue = ''

         SET ROWCOUNT 1 
         SELECT @c_ConfigKey = StorerConfig.ConfigKey, 
                @c_SValue = StorerConfig.SValue 
         FROM #TEMPPICKDETAIL (NOLOCK)
         JOIN StorerConfig (NOLOCK) on ( StorerConfig.StorerKey = #TEMPPICKDETAIL.StorerKey ) 
                                        AND StorerConfig.ConfigKey LIKE 'PID_PG%'  
                                        AND StorerConfig.SValue = '1'
         SET ROWCOUNT 0 

         IF @c_debug = '1'      
         BEGIN      
            SELECT '2. @c_ConfigKey=' + @c_ConfigKey + ' @c_SValue=' + @c_SValue
         END
         ----------------------------------------------------------------------------         
         /* @c_ConfigKey = 'PID_PGALL'                                             */
         ----------------------------------------------------------------------------
         IF @c_ConfigKey = 'PID_PGALL' AND @c_SValue = '1'
         BEGIN

            SELECT @c_row = '0'
                        
            CREATE TABLE #TEMPPICKALL (
	         Rowid			    int IDENTITY(1,1),
	         BUSR5           NVARCHAR(30),
            CLASS           NVARCHAR(10),
            itemclass       NVARCHAR(10),
            SKUGROUP        NVARCHAR(10),
            Style           NVARCHAR(20),
            Color           NVARCHAR(10),
            Size            NVARCHAR(5) NULL, 
            Measurement     NVARCHAR(5) NULL,
            PickslipNo		 NVARCHAR(10) NULL)
                                      
            INSERT INTO #TEMPPICKALL (BUSR5, CLASS, itemclass, SKUGROUP, Style, Color, Size, Measurement, PickslipNo) 
            SELECT SKU.BUSR5, SKU.CLASS, SKU.itemclass, SKU.SKUGROUP, SKU.Style, SKU.Color, SKU.Size, SKU.Measurement, MAX(PickslipNo)
            FROM #TEMPPICKDETAIL (NOLOCK)
            JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
            GROUP BY SKU.BUSR5, SKU.CLASS, SKU.itemclass, SKU.SKUGROUP, SKU.Style, SKU.Color, SKU.Size, SKU.Measurement 
            ORDER BY SKU.BUSR5, SKU.CLASS, SKU.itemclass, SKU.SKUGROUP, SKU.Style, SKU.Color, SKU.Size, SKU.Measurement 

            IF @c_debug = '1'      
            BEGIN      
               SELECT * FROM #TEMPPICKALL (NOLOCK)
            END

		      SELECT @n_rowid = 0 		
   	
            WHILE 1=1 
            BEGIN
			      SELECT @n_rowid = Min(rowid) 
			        FROM #TEMPPICKALL 	
			       WHERE Rowid > @n_rowid

			      IF @n_rowid IS NULL OR @n_rowid = 0 BREAK				

			      Select @c_BUSR5 = BUSR5, 
                      @c_CLASS = CLASS, 
                      @c_itemclass = itemclass, 
                      @c_SKUGROUP = SKUGROUP, 
                      @c_Style = Style, 
                      @c_Color = Color, 
                      @c_Size = Size, 
                      @c_Measurement = Measurement,
                      @c_PickslipNo = PickslipNo
			        from #TEMPPICKALL 
			       Where Rowid = @n_rowid
               

               IF (@c_firsttime = 'N' AND ISNULL(@c_PickslipNo, '') = '') --re-allocation use the existing pickslipno
               BEGIN
                   SELECT @c_PickSlipNo = pickheaderkey, @c_pickheaderkey = pickheaderkey
                   FROM PickHeader (NOLOCK) 
                   WHERE ExternOrderKey = @c_refkey 
                   AND Zone = 'XD'
               END

               IF ISNULL(@c_PickslipNo, '') = ''
               BEGIN
			         EXECUTE nspg_GetKey 
				         'PICKSLIP',
				         8,   
				         @c_pickheaderkey     OUTPUT,
				         @b_success   	      OUTPUT,
				         @n_err       	      OUTPUT,
				         @c_errmsg    	      OUTPUT
      				
			         IF @n_err <> 0 
			         BEGIN
				         select @n_continue = 3
				         Break 
			         END
      				
			         IF @c_type = 'P' 
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END
			         ELSE
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END  -- @c_type = 'P' 
      				
			         select @c_row = Convert(char(10), convert(int, @c_row) + 1) 

                  IF @c_debug = '1'      
                  BEGIN      
                     SELECT ' @c_pickheaderkey =' + @c_pickheaderkey 
                  END

                  BEGIN TRAN 
                  
   	            INSERT INTO PICKHEADER (PickHeaderKey,    WaveKey,    ExternOrderKey, PickType, Zone, TrafficCop)
		            VALUES (@c_pickheaderkey, @c_row, @c_refkey,     '0',      'XD',  '')

                  IF @@ERROR = 0 
                  BEGIN
                     WHILE @@TRANCOUNT > 0 
                        COMMIT TRAN 
                  END 	
                  ELSE
                  BEGIN
                     ROLLBACK TRAN 
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63307   
      		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PickHeader Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                     BREAK 
                  END  -- @@ERROR = 0 

                  IF @n_continue = 1 OR @n_continue = 2  
                  BEGIN
				         BEGIN TRAN 

                     UPDATE #TEMPPICKDETAIL 
                        SET PICKSLIPNO = @c_pickheaderkey 
                        FROM  #TEMPPICKDETAIL
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
                                               AND SKU.BUSR5 = @c_BUSR5
                                               AND SKU.CLASS = @c_CLASS 
                                               AND SKU.itemclass = @c_itemclass 
                                               AND SKU.SKUGROUP = @c_SKUGROUP  
                                               AND SKU.Style = @c_Style 
                                               AND SKU.Color = @c_Color 
                                               AND SKU.Size = @c_Size 
                                               AND SKU.Measurement = @c_Measurement          	
				         SELECT @n_err = @@ERROR
      			
                     IF @n_err = 0 
                     BEGIN
                        WHILE @@TRANCOUNT > 0 
                           COMMIT TRAN 
                     END 	
                     ELSE
                     BEGIN
                        ROLLBACK TRAN 
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63308   
         		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
					         Break
                     END  -- @n_err = 0 

                     IF @c_debug = '1'      
                     BEGIN      
                        SELECT PICKSLIPNO
                        FROM #TEMPPICKDETAIL 
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
                                               AND SKU.BUSR5 = @c_BUSR5
                                               AND SKU.CLASS = @c_CLASS 
                                               AND SKU.itemclass = @c_itemclass 
                                               AND SKU.SKUGROUP = @c_SKUGROUP  
                                               AND SKU.Style = @c_Style 
                                               AND SKU.Color = @c_Color 
                                               AND SKU.Size = @c_Size 
                                               AND SKU.Measurement = @c_Measurement 
                     END

                  END  -- @n_continue = 1 OR @n_continue = 2
               END  -- ISNULL(@c_PickslipNo, '') = ''
               ELSE
                  SELECT @c_pickheaderkey = @c_PickslipNo 


               -- Generate DropID if not data found 
               SELECT @n_rowid1         = 0 
               SELECT @b_break          = '0'  
               SELECT @c_BreakKey       = ''
               SELECT @c_prev_BreakKey  = ''               
               SELECT @b_newgroup       = '0'      

               SET ROWCOUNT 1 		
               WHILE 1=1 
               BEGIN
                  SELECT @c_PICKDETAILKey = ''
                  SELECT @c_ConsigneeKey = ''
                  SELECT @d_DeliveryDate = ''  
                  SELECT @c_sku = ''  
                  SELECT @n_StdGrossWGT = ''  
                  SELECT @n_STDCube = ''  
                  SELECT @n_QtyPick = 0 
                  SELECT @c_CartonType = '' 
                  SELECT @n_MaxWeight = '' 
                  SELECT @n_MaxCube = '' 
 	                SELECT @n_casecnt = 0      
                  SELECT @n_innerpack = 0               
                  SELECT @c_uom = ''


                  SELECT @n_rowid1        = #TEMPPICKDETAIL.rowid, 
                         @c_PICKDETAILKey = #TEMPPICKDETAIL.PICKDETAILKey, 
                         @c_ConsigneeKey  = #TEMPPICKDETAIL.ConsigneeKey,
                         @d_DeliveryDate  = #TEMPPICKDETAIL.DeliveryDate,
                         @c_sku           = SKU.SKU,      
                         @n_StdGrossWGT   = ISNULL(SKU.StdGrossWGT,0),           
                         @n_STDCube       = ISNULL(SKU.STDCube,0),      
                         @n_QtyPick       = ISNULL(#TEMPPICKDETAIL.Qty,0), 
                         @c_CartonType    = Cartonization.CartonType,
                         @n_MaxWeight     = ISNULL(Cartonization.MaxWeight,0),      
                         @n_MaxCube       = ISNULL(Cartonization.[Cube],0),          
                         @n_CaseCnt       = PACK.casecnt,
                         @n_Innerpack     = PACK.innerpack,
                         @c_uom           = #TEMPPICKDETAIL.uom
                  FROM #TEMPPICKDETAIL (NOLOCK)
                  JOIN SKU     (NOLOCK) ON ( #TEMPPICKDETAIL.Storerkey = SKU.StorerKey ) 
                                             AND ( #TEMPPICKDETAIL.Sku = SKU.Sku )
                  JOIN Storer (NOLOCK) on ( Storer.StorerKey = #TEMPPICKDETAIL.StorerKey )      
                  JOIN Cartonization (NOLOCK) on ( Cartonization.CartonizationGroup = Storer.CartonGroup )  
                                             AND ( Cartonization.CartonType = CASE #TEMPPICKDETAIL.UOM WHEN '1' THEN 'Pallet' WHEN '2' THEN 'Pallet' ELSE 'Tote' END )  
                 JOIN Pack (NOLOCK) ON ( #TEMPPICKDETAIL.Packkey = Pack.Packkey)
	               Where ISNULL(#TEMPPICKDETAIL.Qty,0) > 0      
                  AND   LEN(ISNULL(#TEMPPICKDETAIL.DropID, '')) = 0       
                  AND   SKU.StdGrossWGT <= Cartonization.MaxWeight    -- Not process for wrong setup,  cartonization weight/cube is less then SKU QTY 1     
                  AND   SKU.STDCube <=  Cartonization.[Cube]  
                  AND   (SKU.StdGrossWGT * PACK.casecnt) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.casecnt) <= Cartonization.[Cube]
                  AND   (SKU.StdGrossWGT * PACK.innerpack) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.innerpack) <= Cartonization.[Cube]                  
                  AND   #TEMPPICKDETAIL.Rowid > @n_rowid1
                  AND   SKU.BUSR5 = @c_BUSR5
                  AND   SKU.CLASS = @c_CLASS 
                  AND   SKU.itemclass = @c_itemclass 
                  AND   SKU.SKUGROUP = @c_SKUGROUP  
                  AND   SKU.Style = @c_Style 
                  AND   SKU.Color = @c_Color 
                  AND   SKU.Size = @c_Size 
                  AND   SKU.Measurement = @c_Measurement 
                  Order by #TEMPPICKDETAIL.rowid

	               IF ISNULL(RTRIM(@n_rowid1), 0) = 0 OR ISNULL(RTRIM(@c_ConsigneeKey), '') = ''
                  BEGIN
                     BREAK	
                  END			

                  SELECT @c_BreakKey = ISNULL(RTRIM(@c_ConsigneeKey), '') +'/'+ ISNULL(RTRIM(@d_DeliveryDate), '') 

                  IF @c_debug = '1'      
                  BEGIN         
                     SELECT '@c_prev_BreakKey', @c_prev_BreakKey, '@c_BreakKey', @c_BreakKey      
                  END 

                  IF @c_BreakKey <> @c_prev_BreakKey      
                  BEGIN      
                     SELECT @c_prev_breakkey = @c_breakkey      
                     Select @b_break = '1'
                     SELECT @b_newgroup = '1'      
                  END    

                  -- break DropID      
                  IF  @b_break = '1' 
                  BEGIN 
                     IF @c_debug = '1'      
                     BEGIN        
                        SELECT '@c_CartonType', @c_CartonType       
                        SELECT '@n_MaxWeight', @n_MaxWeight, '@n_MaxCube', @n_MaxCube    
                     END
                     
                     SELECT @b_getdropid = '1'
                     IF @b_newgroup = '1' and @c_uom <> '1'
                     BEGIN
             	         	BEGIN TRAN               
									      INSERT INTO XDPartialPlt (DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7,
                                 									Col8, Col9, Col10, CumWeight, CumCube)
         								SELECT DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7, 
                							Col8, Col9, Col10, CumWeight, CumCube
	         							FROM #TEMPXDPARTIALPLT
                              
					  		        IF @@ERROR = 0 
    		   							BEGIN
              						WHILE @@TRANCOUNT > 0 
                								COMMIT TRAN 
                				  DELETE FROM #TEMPXDPARTIALPLT
         				    		END -- @@ERROR = 0 	
         							  ELSE
         							  BEGIN 
            						  ROLLBACK TRAN 
            						  SELECT @n_continue = 3
            						  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63353   
          							  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         								END  -- @@ERROR <> 0 
                     	
                        SELECT @n_RowId2 = a.Rowid, @c_DropID = a.DropId, @n_CumWeight = a.CumWeight, @n_CumCube = a.CumCube
                        FROM XDPartialPlt a (NOLOCK), PICKDETAIL b (NOLOCK)
                        WHERE a.Consigneekey = @c_ConsigneeKey
                        AND CONVERT(char(8),a.DeliveryDate,1) = CONVERT(char(8),@d_DeliveryDate,1)
                        AND a.Col1 = @c_BUSR5
                        AND a.Col2 = @c_CLASS 
                        AND a.Col3 = @c_itemclass 
                        AND a.Col4 = @c_SKUGROUP  
                        AND a.Col5 = @c_Style 
                        AND a.Col6 = @c_Color 
                        AND a.Col7 = @c_Size 
                        AND a.Col8 = @c_Measurement
                        AND a.DropId = b.DropId             
                         
                        IF @@ROWCOUNT > 0
                        BEGIN
                           SELECT @b_getdropid = '0'
                          
                           BEGIN TRAN
                           DELETE FROM XDPartialPlt WHERE RowId = @n_RowId2
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63350   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END

                        SELECT @b_newgroup = '0'
                     END
                     
                     IF @b_getdropid = '1'
                     BEGIN
                        EXECUTE nspg_GetKey      
                           'PICKToID',      
                           10,      
                           @c_DropID OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      
   
                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        SELECT @n_CumWeight = 0      
                        SELECT @n_CumCube   = 0          
                     END
                     SELECT @n_CurQty    = 0    
                     SELECT @n_CapWeight = 0          
                     SELECT @n_CapCube   = 0  
                     SELECT @c_Remark    = ''  
                     SELECT @b_break     = '0'  
                  END

                  SELECT @n_SplitQty = 0      
                  SELECT @n_CurQty   = @n_QtyPick  

                  -- loop decs to fit in Pallet\Tote Weight\Cube      
                  WHILE @n_CurQty > 0      
                  BEGIN      
                  	
                   	 IF @c_uom = '1'  -- Full pallet
                  	 BEGIN
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100
                        SELECT @b_break = '1'
                        SELECT @c_remark = 'MAX'
                  	    BREAK
                  	 END
                  	 
                     IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) <= @n_MaxWeight AND      
                        @n_CumCube   + ( @n_CurQty * @n_STDCube )     <= @n_MaxCube          
                     BEGIN      
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100
                        
                        IF @b_break = '0'
                        BEGIN
                           BEGIN TRAN
                           IF ( ( SELECT COUNT(RowId) FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID ) > 0 )
                              UPDATE #TEMPXDPARTIALPLT SET CumWeight = @n_CumWeight, CumCube = @n_CumCube
                              WHERE DropId = @c_DropID                                                      
                           ELSE                       
                              INSERT INTO #TEMPXDPARTIALPLT (DropId, Consigneekey, DeliveryDate, Col1, Col2, Col3, Col4,
                                                               Col5, Col6, Col7, Col8, CumWeight, CumCube)
                                                       VALUES (@c_DropID, @c_ConsigneeKey, @d_DeliveryDate, @c_BUSR5, @c_CLASS,
                                                               @c_itemclass, @c_SKUGROUP, @c_Style, @c_Color, @c_Size, @c_Measurement,
                                                               @n_CumWeight, @n_CumCube)
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63351   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert/Update #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END

                        BREAK      
                     END      
                     ELSE      
                     BEGIN      
                     	  IF @c_uom = '2'   -- To ensure a case/inner pack not split to multi PID
                     	  BEGIN
                     	  	 SELECT @n_CurQty = @n_CurQty - @n_casecnt
                     		END                     		
                     	  ELSE
                     	  BEGIN
                     	  	 IF @c_uom = '3'
                        	 		SELECT @n_CurQty = @n_CurQty - @n_innerpack 
                        	 ELSE
                        	 		SELECT @n_CurQty = @n_CurQty - 1      
                        END

                        SELECT @b_break = '1'  -- cause split PickDetail and break Drop ID      
                        IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) > @n_MaxWeight
                        BEGIN
                           SELECT @n_Capacity = @n_CumWeight/@n_MaxWeight*100
                        END 

                        IF @n_CumCube   + ( @n_CurQty * @n_STDCube )     > @n_MaxCube
                        BEGIN
                           SELECT @n_Capacity = @n_CumCube/@n_MaxCube*100
                        END
                        SELECT @c_Remark = 'MAX'
                        
                        BEGIN TRAN                        
                        DELETE FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID
                        IF @@ERROR = 0 
                        BEGIN
                           WHILE @@TRANCOUNT > 0 
                              COMMIT TRAN 
                        END -- @@ERROR = 0 	
                        ELSE
                        BEGIN 
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63352   
            	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                        END  -- @@ERROR <> 0 
                     END      
                  END       
               
                  IF @c_debug = '1'      
                  BEGIN        
                     SELECT '@n_CurQty', @n_CurQty       
                     SELECT '@n_CumWeight', @n_CumWeight       
                     SELECT '@n_CumCube', @n_CumCube            
                  END   
               
                  IF @n_CurQty > 0       
                  BEGIN      
                     IF @n_CurQty <> @n_QtyPick        
                     BEGIN      
                        BEGIN TRAN  
                        SELECT @n_SplitQty = @n_QtyPick  - @n_CurQty      
                  
                        EXECUTE nspg_GetKey      
                           'PICKDETAILKEY',      
                           10,      
                           @c_New_PICKDETAILKey OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      

                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        IF @c_debug = '1'      
                        BEGIN        
                           SELECT '@c_New_PICKDETAILKey', @c_New_PICKDETAILKey      
                        END      
                   
                        -- new pick item for remaining @n_SplitQty    
                        INSERT PICKDETAIL      
                           ( PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,       
                           DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo )      
                        SELECT @c_New_PICKDETAILKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                           '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, '9', ShipFlag, @c_pickheaderkey      
                        FROM PICKDETAIL       
                        WHERE PICKDETAILKey = @c_PICKDETAILKey          
                            
                        IF @@ERROR <> 0     
                        BEGIN     
                           ROLLBACK TRAN  
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + 
                                             ': Insert Into PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END     

			               INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku, Qty, Lot, Loc, ID, Packkey, 
                                                     PickSlipNo, UOM, DropID, ConsigneeKey, C_Company, Priority, DeliveryDate, Capacity, Remark, PrintedFlag)
			               SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, PD.Lot, PD.Loc, PD.ID, PD.Packkey, 
                               PD.PickSlipNo, PD.UOM, PD.DropID, OH.CONSIGNEEKEY, OH.C_COMPANY, OH.Priority, OH.DeliveryDate, @n_Capacity, @c_Remark, @c_PrintedFlag
			                 FROM ORDERDETAIL OD (NOLOCK), PICKDETAIL PD (NOLOCK), ORDERS OH (NOLOCK) 
			                WHERE PD.ORDERKEY = OD.ORDERKEY 
				               AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER 
                           AND OH.ORDERKEY = OD.ORDERKEY
				               AND PD.PICKDETAILKey = @c_New_PICKDETAILKey   
                     
                        IF @@ERROR <> 0 
                        BEGIN
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63302   
   		                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           BREAK  
                        END  -- @@ERROR <> 0  
             
                        -- existing DROPID carton allow qty (@n_CurQty)   , remaining qty  (@n_SplitQty) next DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,      
                            UOMQTY = CASE UOM WHEN '6' THEN @n_CurQty ELSE UOMQty END ,     
                            DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey      
  
                        IF @@ERROR <> 0       
                        BEGIN  
                           ROLLBACK TRAN     
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END  

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,
                            DropID = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey  
                     END      
                     ELSE      
                     BEGIN      
                        -- Full Pickdetail item Qty for the DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey    
    
                        IF @@ERROR <> 0       
                        BEGIN      
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END   

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set DropID   = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,     
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey       
                     END  -- @n_CurQty <> @n_QtyPick          
                  END  -- @n_CurQty > 0      
                  ELSE -- @n_CurQty = 0
                    SELECT @n_rowid1 = @n_rowid1 - 1  -- Whole pickdetail line cannot fit reculculate with new pallet id

               END  -- WHILE 1=1 
               SET ROWCOUNT 0 
               -- Generate DropID if not data found 

		      END  -- WHILE 1=1 
		                  
            DROP Table #TEMPPICKALL

         END  
         ----------------------------------------------------------------------------         
         /* END @c_ConfigKey = 'PID_PGALL'                                         */
         ----------------------------------------------------------------------------
         ----------------------------------------------------------------------------         
         /* @c_ConfigKey = 'PID_PG1'                                               */
         ----------------------------------------------------------------------------
         IF @c_ConfigKey = 'PID_PG1' AND @c_SValue = '1'
         BEGIN

            SELECT @c_row = '0'
            
            CREATE TABLE #TEMPPICK1 (
	         Rowid			    int IDENTITY(1,1),
	         BUSR5           NVARCHAR(30),
            PickslipNo		 NVARCHAR(10) NULL)  

            INSERT INTO #TEMPPICK1 (BUSR5, PickslipNo) 
            SELECT SKU.BUSR5, MAX(PickslipNo)
            FROM #TEMPPICKDETAIL (NOLOCK)
            JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
            GROUP BY SKU.BUSR5
            ORDER BY SKU.BUSR5 

            IF @c_debug = '1'      
            BEGIN      
               SELECT * FROM #TEMPPICK1 (NOLOCK)
            END

		      SELECT @n_rowid = 0 		
   	
            WHILE 1=1 
            BEGIN
			      SELECT @n_rowid = Min(rowid) 
			        FROM #TEMPPICK1 	
			       WHERE Rowid > @n_rowid

			      IF @n_rowid IS NULL OR @n_rowid = 0 BREAK				

			      Select @c_BUSR5 = BUSR5,
                      @c_PickslipNo = PickslipNo
			        from #TEMPPICK1 
			       Where Rowid = @n_rowid

               IF (@c_firsttime = 'N' AND ISNULL(@c_PickslipNo, '') = '') --re-allocation use the existing pickslipno
               BEGIN
                   SELECT @c_PickSlipNo = pickheaderkey, @c_pickheaderkey = pickheaderkey
                   FROM PickHeader (NOLOCK) 
                   WHERE ExternOrderKey = @c_refkey 
                   AND Zone = 'XD'
               END

               IF ISNULL(@c_PickslipNo, '') = ''
               BEGIN
			         EXECUTE nspg_GetKey 
				         'PICKSLIP',
				         8,   
				         @c_pickheaderkey     OUTPUT,
				         @b_success   	      OUTPUT,
				         @n_err       	      OUTPUT,
				         @c_errmsg    	      OUTPUT
      				
			         IF @n_err <> 0 
			         BEGIN
				         select @n_continue = 3
				         Break 
			         END
      				
			         IF @c_type = 'P' 
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END
			         ELSE
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END  -- @c_type = 'P' 
      				
			         select @c_row = Convert(char(10), convert(int, @c_row) + 1) 

                  IF @c_debug = '1'      
                  BEGIN      
                     SELECT ' @c_pickheaderkey =' + @c_pickheaderkey 
                  END

                  BEGIN TRAN 

			         INSERT INTO PICKHEADER (PickHeaderKey,    WaveKey,    ExternOrderKey, PickType, Zone, TrafficCop)
			         VALUES (@c_pickheaderkey, @c_row, @c_refkey,     '0',      'XD',  '')

                  IF @@ERROR = 0 
                  BEGIN
                     WHILE @@TRANCOUNT > 0 
                        COMMIT TRAN 
                  END 	
                  ELSE
                  BEGIN
                     ROLLBACK TRAN 
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63309   
      		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PickHeader Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                     BREAK 
                  END  -- @@ERROR = 0 

                  IF @n_continue = 1 OR @n_continue = 2  
                  BEGIN
				         BEGIN TRAN 

                     UPDATE #TEMPPICKDETAIL 
                        SET PICKSLIPNO = @c_pickheaderkey 
                        FROM  #TEMPPICKDETAIL
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
                                               AND SKU.BUSR5 = @c_BUSR5
        	
				         SELECT @n_err = @@ERROR
      			
                     IF @n_err = 0 
                     BEGIN
                        WHILE @@TRANCOUNT > 0 
                           COMMIT TRAN 
                     END 	
                     ELSE
                     BEGIN
                        ROLLBACK TRAN 
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63310   
         		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
					         Break
                     END  -- @n_err = 0 

                     IF @c_debug = '1'      
                     BEGIN      
                        SELECT PICKSLIPNO
                        FROM #TEMPPICKDETAIL 
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
                                               AND SKU.BUSR5 = @c_BUSR5
                     END

                  END  -- @n_continue = 1 OR @n_continue = 2
               END  -- ISNULL(@c_PickslipNo, '') = ''
               ELSE
                  SELECT @c_pickheaderkey = @c_PickslipNo 

               -- Generate DropID if not data found 
               SELECT @n_rowid1         = 0 
               SELECT @b_break          = '0'  
               SELECT @c_BreakKey       = ''
               SELECT @c_prev_BreakKey  = ''
               SELECT @b_newgroup       = '0'                     

               SET ROWCOUNT 1 		
               WHILE 1=1 
               BEGIN
                  SELECT @c_PICKDETAILKey = ''
                  SELECT @c_ConsigneeKey = ''
                  SELECT @d_DeliveryDate = ''  
                  SELECT @c_sku = ''  
                  SELECT @n_StdGrossWGT = ''  
                  SELECT @n_STDCube = ''  
                  SELECT @n_QtyPick = 0 
                  SELECT @c_CartonType = '' 
                  SELECT @n_MaxWeight = '' 
                  SELECT @n_MaxCube = '' 
	                SELECT @n_casecnt = 0      
                  SELECT @n_innerpack = 0               
                  SELECT @c_uom = ''

                  SELECT @n_rowid1        = #TEMPPICKDETAIL.rowid, 
                         @c_PICKDETAILKey = #TEMPPICKDETAIL.PICKDETAILKey, 
                         @c_ConsigneeKey  = #TEMPPICKDETAIL.ConsigneeKey,
                         @d_DeliveryDate  = #TEMPPICKDETAIL.DeliveryDate,
                         @c_sku           = SKU.SKU,      
                         @n_StdGrossWGT   = ISNULL(SKU.StdGrossWGT,0),           
                         @n_STDCube       = ISNULL(SKU.STDCube,0),      
                         @n_QtyPick       = ISNULL(#TEMPPICKDETAIL.Qty,0), 
                         @c_CartonType    = Cartonization.CartonType,
                         @n_MaxWeight     = ISNULL(Cartonization.MaxWeight,0),      
                         @n_MaxCube       = ISNULL(Cartonization.[Cube],0),          
                         @n_CaseCnt       = PACK.casecnt,
                         @n_Innerpack     = PACK.innerpack,
                         @c_uom           = #TEMPPICKDETAIL.uom
                  FROM #TEMPPICKDETAIL (NOLOCK)
                  JOIN SKU     (NOLOCK) ON ( #TEMPPICKDETAIL.Storerkey = SKU.StorerKey ) 
                                             AND ( #TEMPPICKDETAIL.Sku = SKU.Sku )
                  JOIN Storer (NOLOCK) on ( Storer.StorerKey = #TEMPPICKDETAIL.StorerKey )      
                  JOIN Cartonization (NOLOCK) on ( Cartonization.CartonizationGroup = Storer.CartonGroup )  
                                             AND ( Cartonization.CartonType = CASE #TEMPPICKDETAIL.UOM WHEN '1' THEN 'Pallet' WHEN '2' THEN 'Pallet' ELSE 'Tote' END )  
                  JOIN Pack (NOLOCK) ON ( #TEMPPICKDETAIL.Packkey = Pack.Packkey)
	               Where ISNULL(#TEMPPICKDETAIL.Qty,0) > 0      
                  AND   LEN(ISNULL(#TEMPPICKDETAIL.DropID, '')) = 0       
                  AND   SKU.StdGrossWGT <= Cartonization.MaxWeight    -- Not process for wrong setup,  cartonization weight/cube is less then SKU QTY 1     
                  AND   SKU.STDCube <=  Cartonization.[Cube]  
                  AND   (SKU.StdGrossWGT * PACK.casecnt) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.casecnt) <= Cartonization.[Cube]
                  AND   (SKU.StdGrossWGT * PACK.innerpack) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.innerpack) <= Cartonization.[Cube]
                  AND   #TEMPPICKDETAIL.Rowid > @n_rowid1
                  AND   SKU.BUSR5 = @c_BUSR5
                  Order by #TEMPPICKDETAIL.rowid

	               IF ISNULL(RTRIM(@n_rowid1), 0) = 0 OR ISNULL(RTRIM(@c_ConsigneeKey), '') = ''
                  BEGIN
                     BREAK	
                  END			

                  SELECT @c_BreakKey = ISNULL(RTRIM(@c_ConsigneeKey), '') +'/'+ ISNULL(RTRIM(@d_DeliveryDate), '') 

                  IF @c_debug = '1'      
                  BEGIN         
                     SELECT '@c_prev_BreakKey', @c_prev_BreakKey, '@c_BreakKey', @c_BreakKey      
                  END 

                  IF @c_BreakKey <> @c_prev_BreakKey      
                  BEGIN      
                     SELECT @c_prev_breakkey = @c_breakkey      
                     Select @b_break = '1'  
                     SELECT @b_newgroup = '1'          
                  END    

                  -- break DropID      
                  IF  @b_break = '1' 
                  BEGIN 
                     IF @c_debug = '1'      
                     BEGIN        
                        SELECT '@c_CartonType', @c_CartonType       
                        SELECT '@n_MaxWeight', @n_MaxWeight, '@n_MaxCube', @n_MaxCube    
                     END      
                     
                     SELECT @b_getdropid = '1'
                     IF @b_newgroup = '1' and @c_uom <> '1'
                     BEGIN
             	         	BEGIN TRAN               
									      INSERT INTO XDPartialPlt (DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7,
                                 									Col8, Col9, Col10, CumWeight, CumCube)
         								SELECT DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7, 
                							Col8, Col9, Col10, CumWeight, CumCube
	         							FROM #TEMPXDPARTIALPLT
                              
					  		        IF @@ERROR = 0 
    		   							BEGIN
              						WHILE @@TRANCOUNT > 0 
                								COMMIT TRAN 
                				  DELETE FROM #TEMPXDPARTIALPLT
         				    		END -- @@ERROR = 0 	
         							  ELSE
         							  BEGIN 
            						  ROLLBACK TRAN 
            						  SELECT @n_continue = 3
            						  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63353   
          							  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         								END  -- @@ERROR <> 0 
                     	
                        SELECT @n_RowId2 = a.Rowid, @c_DropID = a.DropId, @n_CumWeight = a.CumWeight, @n_CumCube = a.CumCube
                        FROM XDPartialPlt a (NOLOCK), pickdetail b (NOLOCK)
                        WHERE a.Consigneekey = @c_ConsigneeKey
                        AND CONVERT(char(8),a.DeliveryDate,1) = CONVERT(char(8),@d_DeliveryDate,1)
                        AND a.Col1 = @c_BUSR5                        
                        AND a.DropId = b.Dropid
                        
                        IF @@ROWCOUNT > 0
                        BEGIN
                           SELECT @b_getdropid = '0'
                          
                           BEGIN TRAN
                           DELETE FROM XDPartialPlt WHERE RowId = @n_RowId2
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63354   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END

                        SELECT @b_newgroup = '0'
                     END
               
                     IF @b_getdropid = '1'
                     BEGIN
                        EXECUTE nspg_GetKey      
                           'PICKToID',      
                           10,      
                           @c_DropID OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      
   
                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        SELECT @n_CumWeight = 0      
                        SELECT @n_CumCube   = 0      
                     END    
                     SELECT @n_CurQty    = 0    
                     SELECT @n_CapWeight = 0          
                     SELECT @n_CapCube   = 0  
                     SELECT @c_Remark    = ''  
                     SELECT @b_break     = '0'  
                  END

                  SELECT @n_SplitQty = 0      
                  SELECT @n_CurQty   = @n_QtyPick  

                  -- loop decs to fit in Pallet\Tote Weight\Cube      
                  WHILE @n_CurQty > 0      
                  BEGIN      

                   	 IF @c_uom = '1'  -- Full pallet
                  	 BEGIN
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100
                        SELECT @b_break = '1'
                        SELECT @c_remark = 'MAX'
                  	    BREAK
                  	 END
                  	                   	
                     IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) <= @n_MaxWeight AND      
                        @n_CumCube   + ( @n_CurQty * @n_STDCube )     <= @n_MaxCube          
                     BEGIN      
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100

                        IF @b_break = '0'
                        BEGIN
                           BEGIN TRAN
                           IF ( ( SELECT COUNT(RowId) FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID ) > 0 )
                              UPDATE #TEMPXDPARTIALPLT SET CumWeight = @n_CumWeight, CumCube = @n_CumCube
                              WHERE DropId = @c_DropID                                                      
                           ELSE                       
                              INSERT INTO #TEMPXDPARTIALPLT (DropId, Consigneekey, DeliveryDate, Col1, CumWeight, CumCube)
                                                       VALUES (@c_DropID, @c_ConsigneeKey, @d_DeliveryDate, @c_BUSR5, @n_CumWeight, @n_CumCube)
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63355   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert/Update #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END

                        BREAK      
                     END      
                     ELSE      
                     BEGIN      
                     	  IF @c_uom = '2'   -- To ensure a case/inner pack not split to multi PID
                     	  BEGIN
                     	  	 SELECT @n_CurQty = @n_CurQty - @n_casecnt
                     		END                     		
                     	  ELSE
                     	  BEGIN
                     	  	 IF @c_uom = '3'
                        	 		SELECT @n_CurQty = @n_CurQty - @n_innerpack 
                        	 ELSE
                        	 		SELECT @n_CurQty = @n_CurQty - 1      
                        END

                        SELECT @b_break = '1'  -- cause split PickDetail and break Drop ID      
                        IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) > @n_MaxWeight
                        BEGIN
                           SELECT @n_Capacity = @n_CumWeight/@n_MaxWeight*100
                        END 

                        IF @n_CumCube   + ( @n_CurQty * @n_STDCube )     > @n_MaxCube
                        BEGIN
                           SELECT @n_Capacity = @n_CumCube/@n_MaxCube*100
                        END
                        SELECT @c_Remark = 'MAX'
                        
                        BEGIN TRAN                        
                        DELETE FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID
                        IF @@ERROR = 0 
                        BEGIN
                           WHILE @@TRANCOUNT > 0 
                              COMMIT TRAN 
                        END -- @@ERROR = 0 	
                        ELSE
                        BEGIN 
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63356   
            	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                        END  -- @@ERROR <> 0 

                     END      
                  END       
               
                  IF @c_debug = '1'      
                  BEGIN        
                     SELECT '@n_CurQty', @n_CurQty       
                     SELECT '@n_CumWeight', @n_CumWeight       
                     SELECT '@n_CumCube', @n_CumCube            
                  END   
               
                  IF @n_CurQty > 0       
                  BEGIN      
                     IF @n_CurQty <> @n_QtyPick        
                     BEGIN      
                        BEGIN TRAN  
                        SELECT @n_SplitQty = @n_QtyPick  - @n_CurQty      
                  
                        EXECUTE nspg_GetKey      
                           'PICKDETAILKEY',      
                           10,      
                           @c_New_PICKDETAILKey OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      

                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        IF @c_debug = '1'      
                        BEGIN        
                           SELECT '@c_New_PICKDETAILKey', @c_New_PICKDETAILKey      
                        END      
                   
                        -- new pick item for remaining @n_SplitQty    
                        INSERT PICKDETAIL      
                           ( PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,       
                           DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo )      
                        SELECT @c_New_PICKDETAILKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                           '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, '9', ShipFlag, @c_pickheaderkey      
                        FROM PICKDETAIL       
                        WHERE PICKDETAILKey = @c_PICKDETAILKey          
                            
                        IF @@ERROR <> 0     
                        BEGIN     
                           ROLLBACK TRAN  
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + 
                                             ': Insert Into PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END     

			               INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku, Qty, Lot, Loc, ID, Packkey, 
                                                     PickSlipNo, UOM, DropID, ConsigneeKey, C_Company, Priority, DeliveryDate, Capacity, Remark, PrintedFlag)
			               SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, PD.Lot, PD.Loc, PD.ID, PD.Packkey, 
                               PD.PickSlipNo, PD.UOM, PD.DropID, OH.CONSIGNEEKEY, OH.C_COMPANY, OH.Priority, OH.DeliveryDate, @n_Capacity, @c_Remark, @c_PrintedFlag
			                 FROM ORDERDETAIL OD (NOLOCK), PICKDETAIL PD (NOLOCK), ORDERS OH (NOLOCK) 
			                WHERE PD.ORDERKEY = OD.ORDERKEY 
				               AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER 
                           AND OH.ORDERKEY = OD.ORDERKEY
				               AND PD.PICKDETAILKey = @c_New_PICKDETAILKey   
                     
                        IF @@ERROR <> 0 
                        BEGIN
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63302   
   		                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           BREAK  
                        END  -- @@ERROR <> 0  
             
                        -- existing DROPID carton allow qty (@n_CurQty)   , remaining qty  (@n_SplitQty) next DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,      
                            UOMQTY = CASE UOM WHEN '6' THEN @n_CurQty ELSE UOMQty END ,     
                            DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey      
  
                        IF @@ERROR <> 0       
                        BEGIN  
                           ROLLBACK TRAN     
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END  

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,
                            DropID = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey  
                     END      
                     ELSE      
                     BEGIN      
                        -- Full Pickdetail item Qty for the DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey    
    
                        IF @@ERROR <> 0       
                        BEGIN      
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END   

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set DropID   = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,     
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey       
                     END  -- @n_CurQty <> @n_QtyPick          
                  END  -- @n_CurQty > 0      
                  ELSE -- @n_CurQty = 0
                    SELECT @n_rowid1 = @n_rowid1 - 1  -- Whole pickdetail line cannot fit reculculate with new pallet id

               END  -- WHILE 1=1 
               SET ROWCOUNT 0 
               -- Generate DropID if not data found 

		      END  -- WHILE 1=1 
		      
            DROP Table #TEMPPICK1

         END  
         ----------------------------------------------------------------------------         
         /* END @c_ConfigKey = 'PID_PG1'                                           */
         ----------------------------------------------------------------------------
         ----------------------------------------------------------------------------         
         /* @c_ConfigKey = 'PID_PG2'                                               */
         ----------------------------------------------------------------------------
         IF @c_ConfigKey = 'PID_PG2' AND @c_SValue = '1'
         BEGIN

            SELECT @c_row = '0'

            CREATE TABLE #TEMPPICK2 (
	         Rowid			    int IDENTITY(1,1),
            CLASS           NVARCHAR(10),
            PickslipNo		 NVARCHAR(10) NULL)  

            INSERT INTO #TEMPPICK2 (CLASS, PickslipNo) 
            SELECT SKU.CLASS, MAX(PickslipNo)
            FROM #TEMPPICKDETAIL (NOLOCK)
            JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
            GROUP BY SKU.CLASS
            ORDER BY SKU.CLASS

            IF @c_debug = '1'      
            BEGIN      
               SELECT * FROM #TEMPPICK2 (NOLOCK)
            END

		      SELECT @n_rowid = 0 		
   	
            WHILE 1=1 
            BEGIN
			      SELECT @n_rowid = Min(rowid) 
			        FROM #TEMPPICK2 	
			       WHERE Rowid > @n_rowid

			      IF @n_rowid IS NULL OR @n_rowid = 0 BREAK				

			      Select @c_CLASS = CLASS,
                      @c_PickslipNo = PickslipNo
			        from #TEMPPICK2 
			       Where Rowid = @n_rowid

               IF (@c_firsttime = 'N' AND ISNULL(@c_PickslipNo, '') = '') --re-allocation use the existing pickslipno
               BEGIN
                   SELECT @c_PickSlipNo = pickheaderkey, @c_pickheaderkey = pickheaderkey
                   FROM PickHeader (NOLOCK) 
                   WHERE ExternOrderKey = @c_refkey 
                   AND Zone = 'XD'
               END

               IF ISNULL(@c_PickslipNo, '') = ''
               BEGIN
			         EXECUTE nspg_GetKey 
				         'PICKSLIP',
				         8,   
				         @c_pickheaderkey     OUTPUT,
				         @b_success   	      OUTPUT,
				         @n_err       	      OUTPUT,
				         @c_errmsg    	      OUTPUT
      				
			         IF @n_err <> 0 
			         BEGIN
				         select @n_continue = 3
				         Break 
			         END
      				
			         IF @c_type = 'P' 
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END
			         ELSE
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END  -- @c_type = 'P' 
      				
			         select @c_row = Convert(char(10), convert(int, @c_row) + 1) 

                  IF @c_debug = '1'      
                  BEGIN      
                     SELECT ' @c_pickheaderkey =' + @c_pickheaderkey 
                  END

                  BEGIN TRAN 

			         INSERT INTO PICKHEADER (PickHeaderKey,    WaveKey,    ExternOrderKey, PickType, Zone, TrafficCop)
			         VALUES (@c_pickheaderkey, @c_row, @c_refkey,     '0',      'XD',  '')

                  IF @@ERROR = 0 
                  BEGIN
                     WHILE @@TRANCOUNT > 0 
                        COMMIT TRAN 
                  END 	
                  ELSE
                  BEGIN
                     ROLLBACK TRAN 
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63311   
      		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PickHeader Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                     BREAK 
                  END  -- @@ERROR = 0 

                  IF @n_continue = 1 OR @n_continue = 2  
                  BEGIN
				         BEGIN TRAN 

                     UPDATE #TEMPPICKDETAIL 
                        SET PICKSLIPNO = @c_pickheaderkey 
                        FROM  #TEMPPICKDETAIL
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
                                               AND SKU.CLASS = @c_CLASS         	
				         SELECT @n_err = @@ERROR
      			
                     IF @n_err = 0 
                     BEGIN
                        WHILE @@TRANCOUNT > 0 
                           COMMIT TRAN 
                     END 	
                     ELSE
                     BEGIN
                        ROLLBACK TRAN 
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63312   
         		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
					         Break
                     END  -- @n_err = 0 

                     IF @c_debug = '1'      
                     BEGIN      
                        SELECT PICKSLIPNO
                        FROM #TEMPPICKDETAIL 
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU )
                                               AND SKU.CLASS = @c_CLASS
                     END

                  END  -- @n_continue = 1 OR @n_continue = 2
               END  -- ISNULL(@c_PickslipNo, '') = ''
               ELSE
                  SELECT @c_pickheaderkey = @c_PickslipNo 

               -- Generate DropID if not data found 
               SELECT @n_rowid1         = 0 
               SELECT @b_break          = '0'  
               SELECT @c_BreakKey       = ''
               SELECT @c_prev_BreakKey  = ''
               SELECT @b_newgroup       = '0'

               SET ROWCOUNT 1 		
               WHILE 1=1 
               BEGIN
                  SELECT @c_PICKDETAILKey = ''
                  SELECT @c_ConsigneeKey = ''
                  SELECT @d_DeliveryDate = ''  
                  SELECT @c_sku = ''  
                  SELECT @n_StdGrossWGT = ''  
                  SELECT @n_STDCube = ''  
                  SELECT @n_QtyPick = 0 
                  SELECT @c_CartonType = '' 
                  SELECT @n_MaxWeight = '' 
                  SELECT @n_MaxCube = '' 
	                SELECT @n_casecnt = 0      
                  SELECT @n_innerpack = 0               
                  SELECT @c_uom = ''

                  SELECT @n_rowid1        = #TEMPPICKDETAIL.rowid, 
                         @c_PICKDETAILKey = #TEMPPICKDETAIL.PICKDETAILKey, 
                         @c_ConsigneeKey  = #TEMPPICKDETAIL.ConsigneeKey,
                         @d_DeliveryDate  = #TEMPPICKDETAIL.DeliveryDate,
                         @c_sku           = SKU.SKU,      
                         @n_StdGrossWGT   = ISNULL(SKU.StdGrossWGT,0),           
                         @n_STDCube       = ISNULL(SKU.STDCube,0),      
                         @n_QtyPick       = ISNULL(#TEMPPICKDETAIL.Qty,0), 
                         @c_CartonType    = Cartonization.CartonType,
                         @n_MaxWeight     = ISNULL(Cartonization.MaxWeight,0),      
                         @n_MaxCube       = ISNULL(Cartonization.[Cube],0),
                         @n_CaseCnt       = PACK.casecnt,
                         @n_Innerpack     = PACK.innerpack,
                         @c_uom           = #TEMPPICKDETAIL.uom
                  FROM #TEMPPICKDETAIL (NOLOCK)
                  JOIN SKU     (NOLOCK) ON ( #TEMPPICKDETAIL.Storerkey = SKU.StorerKey ) 
                                             AND ( #TEMPPICKDETAIL.Sku = SKU.Sku )
                  JOIN Storer (NOLOCK) on ( Storer.StorerKey = #TEMPPICKDETAIL.StorerKey )      
                  JOIN Cartonization (NOLOCK) on ( Cartonization.CartonizationGroup = Storer.CartonGroup )  
                                             AND ( Cartonization.CartonType = CASE #TEMPPICKDETAIL.UOM WHEN '1' THEN 'Pallet' WHEN '2' THEN 'Pallet' ELSE 'Tote' END )  
                  JOIN Pack (NOLOCK) ON ( #TEMPPICKDETAIL.Packkey = Pack.Packkey)
	               Where ISNULL(#TEMPPICKDETAIL.Qty,0) > 0      
                  AND   LEN(ISNULL(#TEMPPICKDETAIL.DropID, '')) = 0       
                  AND   SKU.StdGrossWGT <= Cartonization.MaxWeight    -- Not process for wrong setup,  cartonization weight/cube is less then SKU QTY 1     
                  AND   SKU.STDCube <=  Cartonization.[Cube]  
                  AND   (SKU.StdGrossWGT * PACK.casecnt) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.casecnt) <= Cartonization.[Cube]
                  AND   (SKU.StdGrossWGT * PACK.innerpack) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.innerpack) <= Cartonization.[Cube]
                  AND   #TEMPPICKDETAIL.Rowid > @n_rowid1
                  AND   SKU.Class = @c_CLASS
                  Order by #TEMPPICKDETAIL.rowid

	               IF ISNULL(RTRIM(@n_rowid1), 0) = 0 OR ISNULL(RTRIM(@c_ConsigneeKey), '') = ''
                  BEGIN
                     BREAK	
                  END			

                  SELECT @c_BreakKey = ISNULL(RTRIM(@c_ConsigneeKey), '') +'/'+ ISNULL(RTRIM(@d_DeliveryDate), '') 

                  IF @c_debug = '1'      
                  BEGIN         
                     SELECT '@c_prev_BreakKey', @c_prev_BreakKey, '@c_BreakKey', @c_BreakKey      
                  END 

                  IF @c_BreakKey <> @c_prev_BreakKey      
                  BEGIN      
                     SELECT @c_prev_breakkey = @c_breakkey      
                     Select @b_break = '1'      
                     SELECT @b_newgroup = '1'      
                  END    

                  -- break DropID      
                  IF  @b_break = '1' 
                  BEGIN 
                     IF @c_debug = '1'      
                     BEGIN        
                        SELECT '@c_CartonType', @c_CartonType       
                        SELECT '@n_MaxWeight', @n_MaxWeight, '@n_MaxCube', @n_MaxCube    
                     END      
                     
                     SELECT @b_getdropid = '1'
                     IF @b_newgroup = '1' and @c_uom <> '1'
                     BEGIN
             	         	BEGIN TRAN               
									      INSERT INTO XDPartialPlt (DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7,
                                 									Col8, Col9, Col10, CumWeight, CumCube)
         								SELECT DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7, 
                							Col8, Col9, Col10, CumWeight, CumCube
	         							FROM #TEMPXDPARTIALPLT
                              
					  		        IF @@ERROR = 0 
    		   							BEGIN
              						WHILE @@TRANCOUNT > 0 
                								COMMIT TRAN 
                				  DELETE FROM #TEMPXDPARTIALPLT
         				    		END -- @@ERROR = 0 	
         							  ELSE
         							  BEGIN 
            						  ROLLBACK TRAN 
            						  SELECT @n_continue = 3
            						  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63353   
          							  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         								END  -- @@ERROR <> 0 

                        SELECT @n_RowId2 = a.Rowid, @c_DropID = a.DropId, @n_CumWeight = a.CumWeight, @n_CumCube = a.CumCube
                        FROM XDPartialPlt a (NOLOCK), pickdetail b (NOLOCK) 
                        WHERE a.Consigneekey = @c_ConsigneeKey
                        AND CONVERT(char(8),a.DeliveryDate,1) = CONVERT(char(8),@d_DeliveryDate,1)
                        AND a.Col1 = @c_CLASS
                        AND a.DropId =  b.DropId
                        
                        IF @@ROWCOUNT > 0
                        BEGIN
                           SELECT @b_getdropid = '0'
                          
                           BEGIN TRAN
                           DELETE FROM XDPartialPlt WHERE RowId = @n_RowId2
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63356   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END

                        SELECT @b_newgroup = '0'
                     END
                     
                     IF @b_getdropid = '1'
                     BEGIN               
                        EXECUTE nspg_GetKey      
                           'PICKToID',      
                           10,      
                           @c_DropID OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      
   
                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        SELECT @n_CumWeight = 0      
                        SELECT @n_CumCube   = 0    
                     END      
                     SELECT @n_CurQty    = 0    
                     SELECT @n_CapWeight = 0          
                     SELECT @n_CapCube   = 0  
                     SELECT @c_Remark    = ''  
                     SELECT @b_break     = '0'  
                  END

                  SELECT @n_SplitQty = 0      
                  SELECT @n_CurQty   = @n_QtyPick  

                  -- loop decs to fit in Pallet\Tote Weight\Cube      
                  WHILE @n_CurQty > 0  
                  BEGIN      
                  	
                  	 IF @c_uom = '1'  -- Full pallet
                  	 BEGIN
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100
                        SELECT @b_break = '1'
                        SELECT @c_remark = 'MAX'
                  	    BREAK
                  	 END
                  	
                     IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) <= @n_MaxWeight AND      
                        @n_CumCube   + ( @n_CurQty * @n_STDCube )     <= @n_MaxCube          
                     BEGIN      
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100

                        IF @b_break = '0'
                        BEGIN                        
                           BEGIN TRAN
                           IF ( ( SELECT COUNT(RowId) FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID ) > 0 )
                              UPDATE #TEMPXDPARTIALPLT SET CumWeight = @n_CumWeight, CumCube = @n_CumCube
                              WHERE DropId = @c_DropID                                                      
                           ELSE                       
                              INSERT INTO #TEMPXDPARTIALPLT (DropId, Consigneekey, DeliveryDate, Col1, CumWeight, CumCube)
                                                       VALUES (@c_DropID, @c_ConsigneeKey, @d_DeliveryDate, @c_CLASS, @n_CumWeight, @n_CumCube)
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63357   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert/Update #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END   

                        BREAK      
                     END      
                     ELSE      
                     BEGIN 
                     	  IF @c_uom = '2'   -- To ensure a case/inner pack not split to multi PID
                     	  BEGIN
                     	  	 SELECT @n_CurQty = @n_CurQty - @n_casecnt
                     		END                     		
                     	  ELSE
                     	  BEGIN
                     	  	 IF @c_uom = '3'
                        	 		SELECT @n_CurQty = @n_CurQty - @n_innerpack 
                        	 ELSE
                        	 		SELECT @n_CurQty = @n_CurQty - 1      
                        END
                        
                        SELECT @b_break = '1'  -- cause split PickDetail and break Drop ID      
                        IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) > @n_MaxWeight
                        BEGIN
                           SELECT @n_Capacity = @n_CumWeight/@n_MaxWeight*100
                        END 

                        IF @n_CumCube   + ( @n_CurQty * @n_STDCube )     > @n_MaxCube
                        BEGIN
                           SELECT @n_Capacity = @n_CumCube/@n_MaxCube*100
                        END
                        SELECT @c_Remark = 'MAX'
                        
                        BEGIN TRAN                        
                        DELETE FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID
                        IF @@ERROR = 0 
                        BEGIN
                           WHILE @@TRANCOUNT > 0 
                              COMMIT TRAN 
                        END -- @@ERROR = 0 	
                        ELSE
                        BEGIN 
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63358   
            	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                        END  -- @@ERROR <> 0 
                     END      
                  END       
               
                  IF @c_debug = '1'      
                  BEGIN        
                     SELECT '@n_CurQty', @n_CurQty       
                     SELECT '@n_CumWeight', @n_CumWeight       
                     SELECT '@n_CumCube', @n_CumCube            
                  END   
               
                  IF @n_CurQty > 0       
                  BEGIN      
                     IF @n_CurQty <> @n_QtyPick        
                     BEGIN      
                        BEGIN TRAN  
                        SELECT @n_SplitQty = @n_QtyPick  - @n_CurQty      
                  
                        EXECUTE nspg_GetKey      
                           'PICKDETAILKEY',      
                           10,      
                           @c_New_PICKDETAILKey OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      

                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        IF @c_debug = '1'      
                        BEGIN        
                           SELECT '@c_New_PICKDETAILKey', @c_New_PICKDETAILKey      
                        END      
                   
                        -- new pick item for remaining @n_SplitQty    
                        INSERT PICKDETAIL      
                           ( PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,       
                           DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo )      
                        SELECT @c_New_PICKDETAILKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                           '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, '9', ShipFlag, @c_pickheaderkey      
                        FROM PICKDETAIL       
                        WHERE PICKDETAILKey = @c_PICKDETAILKey          
                            
                        IF @@ERROR <> 0     
                        BEGIN     
                           ROLLBACK TRAN  
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + 
                                             ': Insert Into PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END     

			               INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku, Qty, Lot, Loc, ID, Packkey, 
                                                     PickSlipNo, UOM, DropID, ConsigneeKey, C_Company, Priority, DeliveryDate, Capacity, Remark, PrintedFlag)
			               SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, PD.Lot, PD.Loc, PD.ID, PD.Packkey, 
                               PD.PickSlipNo, PD.UOM, PD.DropID, OH.CONSIGNEEKEY, OH.C_COMPANY, OH.Priority, OH.DeliveryDate, @n_Capacity, @c_Remark, @c_PrintedFlag
			                 FROM ORDERDETAIL OD (NOLOCK), PICKDETAIL PD (NOLOCK), ORDERS OH (NOLOCK) 
			                WHERE PD.ORDERKEY = OD.ORDERKEY 
				               AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER 
                           AND OH.ORDERKEY = OD.ORDERKEY
				               AND PD.PICKDETAILKey = @c_New_PICKDETAILKey   
                     
                        IF @@ERROR <> 0 
                        BEGIN
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63302   
   		                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           BREAK  
                        END  -- @@ERROR <> 0  
             
                        -- existing DROPID carton allow qty (@n_CurQty)   , remaining qty  (@n_SplitQty) next DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,      
                            UOMQTY = CASE UOM WHEN '6' THEN @n_CurQty ELSE UOMQty END ,     
                            DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey      
  
                        IF @@ERROR <> 0       
                        BEGIN  
                           ROLLBACK TRAN     
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END  

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,
                            DropID = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey  
                     END      
                     ELSE      
                     BEGIN      
                        -- Full Pickdetail item Qty for the DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey    
    
                        IF @@ERROR <> 0       
                        BEGIN      
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END   

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set DropID   = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)), 
                            PickslipNo = @c_pickheaderkey,
                            Remark = @c_Remark
												WHERE PICKDETAILKey = @c_PICKDETAILKey       
                     END  -- @n_CurQty <> @n_QtyPick          
                  END  -- @n_CurQty > 0      
                  ELSE -- @n_CurQty = 0
                    SELECT @n_rowid1 = @n_rowid1 - 1  -- Whole pickdetail line cannot fit reculculate with new pallet id

               END  -- WHILE 1=1 
               SET ROWCOUNT 0 
               -- Generate DropID if not data found 

		      END  -- WHILE 1=1 

            DROP Table #TEMPPICK2

         END  
         ----------------------------------------------------------------------------         
         /* END @c_ConfigKey = 'PID_PG2'                                           */
         ----------------------------------------------------------------------------
         ----------------------------------------------------------------------------         
         /* @c_ConfigKey = 'PID_PG3'                                               */
         ----------------------------------------------------------------------------
         IF @c_ConfigKey = 'PID_PG3' AND @c_SValue = '1'
         BEGIN

            SELECT @c_row = '0'

            CREATE TABLE #TEMPPICK3 (
	         Rowid			    int IDENTITY(1,1),
            itemclass       NVARCHAR(10),
            PickslipNo		 NVARCHAR(10) NULL)  

            INSERT INTO #TEMPPICK3 (itemclass, PickslipNo) 
            SELECT SKU.itemclass, MAX(PickslipNo)
            FROM #TEMPPICKDETAIL (NOLOCK)
            JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
            GROUP BY SKU.itemclass
            ORDER BY SKU.itemclass

            IF @c_debug = '1'      
            BEGIN      
               SELECT * FROM #TEMPPICK3 (NOLOCK)
            END

		      SELECT @n_rowid = 0 		
   	
            WHILE 1=1 
            BEGIN
			      SELECT @n_rowid = Min(rowid) 
			        FROM #TEMPPICK3 	
			       WHERE Rowid > @n_rowid

			      IF @n_rowid IS NULL OR @n_rowid = 0 BREAK				

			      Select @c_itemclass = itemclass,
                      @c_PickslipNo = PickslipNo
			        from #TEMPPICK3 
			       Where Rowid = @n_rowid

               IF (@c_firsttime = 'N' AND ISNULL(@c_PickslipNo, '') = '') --re-allocation use the existing pickslipno
               BEGIN
                   SELECT @c_PickSlipNo = pickheaderkey, @c_pickheaderkey = pickheaderkey
                   FROM PickHeader (NOLOCK) 
                   WHERE ExternOrderKey = @c_refkey 
                   AND Zone = 'XD'
               END

               IF ISNULL(@c_PickslipNo, '') = ''
               BEGIN
			         EXECUTE nspg_GetKey 
				         'PICKSLIP',
				         8,   
				         @c_pickheaderkey     OUTPUT,
				         @b_success   	      OUTPUT,
				         @n_err       	      OUTPUT,
				         @c_errmsg    	      OUTPUT
      				
			         IF @n_err <> 0 
			         BEGIN
				         select @n_continue = 3
				         Break 
			         END
      				
			         IF @c_type = 'P' 
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END
			         ELSE
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END  -- @c_type = 'P' 
      				
			         select @c_row = Convert(char(10), convert(int, @c_row) + 1) 

                  IF @c_debug = '1'      
                  BEGIN      
                     SELECT ' @c_pickheaderkey =' + @c_pickheaderkey 
                  END

                  BEGIN TRAN 

			         INSERT INTO PICKHEADER (PickHeaderKey,    WaveKey,    ExternOrderKey, PickType, Zone, TrafficCop)
			         VALUES (@c_pickheaderkey, @c_row, @c_refkey,     '0',      'XD',  '')

                  IF @@ERROR = 0 
                  BEGIN
                     WHILE @@TRANCOUNT > 0 
                        COMMIT TRAN 
                  END 	
                  ELSE
                  BEGIN
                     ROLLBACK TRAN 
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63313   
      		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PickHeader Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                     BREAK 
                  END  -- @@ERROR = 0 

                  IF @n_continue = 1 OR @n_continue = 2  
                  BEGIN
				         BEGIN TRAN 

                     UPDATE #TEMPPICKDETAIL 
                        SET PICKSLIPNO = @c_pickheaderkey 
                        FROM  #TEMPPICKDETAIL
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU )
                                               AND SKU.itemclass = @c_itemclass      	
				         SELECT @n_err = @@ERROR
      			
                     IF @n_err = 0 
                     BEGIN
                        WHILE @@TRANCOUNT > 0 
                           COMMIT TRAN 
                     END 	
                     ELSE
                     BEGIN
                        ROLLBACK TRAN 
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63314   
         		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
					         Break
                     END  -- @n_err = 0 

                     IF @c_debug = '1'      
                     BEGIN      
                        SELECT PICKSLIPNO
                        FROM #TEMPPICKDETAIL 
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU )
                                               AND SKU.itemclass = @c_itemclass 
                     END

                  END  -- @n_continue = 1 OR @n_continue = 2
               END  -- ISNULL(@c_PickslipNo, '') = ''
               ELSE
                  SELECT @c_pickheaderkey = @c_PickslipNo 

               -- Generate DropID if not data found 
               SELECT @n_rowid1         = 0 
               SELECT @b_break          = '0'  
               SELECT @c_BreakKey       = ''
               SELECT @c_prev_BreakKey  = ''  
               SELECT @b_newgroup       = '0'                   

               SET ROWCOUNT 1 		
               WHILE 1=1 
               BEGIN
                  SELECT @c_PICKDETAILKey = ''
                  SELECT @c_ConsigneeKey = ''
                  SELECT @d_DeliveryDate = ''  
                  SELECT @c_sku = ''  
                  SELECT @n_StdGrossWGT = ''  
                  SELECT @n_STDCube = ''  
                  SELECT @n_QtyPick = 0 
                  SELECT @c_CartonType = '' 
                  SELECT @n_MaxWeight = '' 
                  SELECT @n_MaxCube = '' 
	                SELECT @n_casecnt = 0      
                  SELECT @n_innerpack = 0               
                  SELECT @c_uom = ''

                  SELECT @n_rowid1        = #TEMPPICKDETAIL.rowid, 
                         @c_PICKDETAILKey = #TEMPPICKDETAIL.PICKDETAILKey, 
                         @c_ConsigneeKey  = #TEMPPICKDETAIL.ConsigneeKey,
                         @d_DeliveryDate  = #TEMPPICKDETAIL.DeliveryDate,
                         @c_sku           = SKU.SKU,      
                         @n_StdGrossWGT   = ISNULL(SKU.StdGrossWGT,0),           
                         @n_STDCube       = ISNULL(SKU.STDCube,0),      
                         @n_QtyPick       = ISNULL(#TEMPPICKDETAIL.Qty,0), 
                         @c_CartonType    = Cartonization.CartonType,
                         @n_MaxWeight     = ISNULL(Cartonization.MaxWeight,0),      
                         @n_MaxCube       = ISNULL(Cartonization.[Cube],0),          
                         @n_CaseCnt       = PACK.casecnt,
                         @n_Innerpack     = PACK.innerpack,
                         @c_uom           = #TEMPPICKDETAIL.uom
                  FROM #TEMPPICKDETAIL (NOLOCK)
                  JOIN SKU     (NOLOCK) ON ( #TEMPPICKDETAIL.Storerkey = SKU.StorerKey ) 
                                             AND ( #TEMPPICKDETAIL.Sku = SKU.Sku )
                  JOIN Storer (NOLOCK) on ( Storer.StorerKey = #TEMPPICKDETAIL.StorerKey )      
                  JOIN Cartonization (NOLOCK) on ( Cartonization.CartonizationGroup = Storer.CartonGroup )  
                                             AND ( Cartonization.CartonType = CASE #TEMPPICKDETAIL.UOM WHEN '1' THEN 'Pallet' WHEN '2' THEN 'Pallet' ELSE 'Tote' END )  
                  JOIN Pack (NOLOCK) ON ( #TEMPPICKDETAIL.Packkey = Pack.Packkey)
	               Where ISNULL(#TEMPPICKDETAIL.Qty,0) > 0      
                  AND   LEN(ISNULL(#TEMPPICKDETAIL.DropID, '')) = 0       
                  AND   SKU.StdGrossWGT <= Cartonization.MaxWeight    -- Not process for wrong setup,  cartonization weight/cube is less then SKU QTY 1     
                  AND   SKU.STDCube <=  Cartonization.[Cube]  
                  AND   (SKU.StdGrossWGT * PACK.casecnt) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.casecnt) <= Cartonization.[Cube]
                  AND   (SKU.StdGrossWGT * PACK.innerpack) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.innerpack) <= Cartonization.[Cube]
                  AND   #TEMPPICKDETAIL.Rowid > @n_rowid1
                  AND   SKU.itemclass = @c_itemclass
                  Order by #TEMPPICKDETAIL.rowid

	               IF ISNULL(RTRIM(@n_rowid1), 0) = 0 OR ISNULL(RTRIM(@c_ConsigneeKey), '') = ''
                  BEGIN
                     BREAK	
                  END			

                  SELECT @c_BreakKey = ISNULL(RTRIM(@c_ConsigneeKey), '') +'/'+ ISNULL(RTRIM(@d_DeliveryDate), '') 

                  IF @c_debug = '1'      
                  BEGIN         
                     SELECT '@c_prev_BreakKey', @c_prev_BreakKey, '@c_BreakKey', @c_BreakKey      
                  END 

                  IF @c_BreakKey <> @c_prev_BreakKey      
                  BEGIN      
                     SELECT @c_prev_breakkey = @c_breakkey      
                     Select @b_break = '1'      
                     SELECT @b_newgroup = '1'      
                  END    

                  -- break DropID      
                  IF  @b_break = '1' 
                  BEGIN 
                     IF @c_debug = '1'      
                     BEGIN        
                        SELECT '@c_CartonType', @c_CartonType       
                        SELECT '@n_MaxWeight', @n_MaxWeight, '@n_MaxCube', @n_MaxCube    
                     END      
                     
                     SELECT @b_getdropid = '1'
                     IF @b_newgroup = '1' and @c_uom <> '1'
                     BEGIN
             	         	BEGIN TRAN               
									      INSERT INTO XDPartialPlt (DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7,
                                 									Col8, Col9, Col10, CumWeight, CumCube)
         								SELECT DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7, 
                							Col8, Col9, Col10, CumWeight, CumCube
	         							FROM #TEMPXDPARTIALPLT
                              
					  		        IF @@ERROR = 0 
    		   							BEGIN
              						WHILE @@TRANCOUNT > 0 
                								COMMIT TRAN 
                				  DELETE FROM #TEMPXDPARTIALPLT
         				    		END -- @@ERROR = 0 	
         							  ELSE
         							  BEGIN 
            						  ROLLBACK TRAN 
            						  SELECT @n_continue = 3
            						  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63353   
          							  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         								END  -- @@ERROR <> 0 
                     	
                        SELECT @n_RowId2 = a.Rowid, @c_DropID = a.DropId, @n_CumWeight = a.CumWeight, @n_CumCube = a.CumCube
                        FROM XDPartialPlt a (NOLOCK), pickdetail b (NOLOCK)
                        WHERE a.Consigneekey = @c_ConsigneeKey
                        AND CONVERT(char(8),a.DeliveryDate,1) = CONVERT(char(8),@d_DeliveryDate,1)
                        AND a.Col1 = @c_itemclass
                        AND a.DropId = b.DropId
                        
                        IF @@ROWCOUNT > 0
                        BEGIN
                           SELECT @b_getdropid = '0'
                          
                           BEGIN TRAN
                           DELETE FROM XDPartialPlt WHERE RowId = @n_RowId2
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63359   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END

                        SELECT @b_newgroup = '0'
                     END
                     
                     IF @b_getdropid = '1'
                     BEGIN               
                        EXECUTE nspg_GetKey      
                           'PICKToID',      
                           10,      
                           @c_DropID OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      
   
                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        SELECT @n_CumWeight = 0      
                        SELECT @n_CumCube   = 0 
                     END         
                     SELECT @n_CurQty    = 0    
                     SELECT @n_CapWeight = 0          
                     SELECT @n_CapCube   = 0  
                     SELECT @c_Remark    = ''  
                     SELECT @b_break     = '0'  
                  END

                  SELECT @n_SplitQty = 0      
                  SELECT @n_CurQty   = @n_QtyPick  

                  -- loop decs to fit in Pallet\Tote Weight\Cube      
                  WHILE @n_CurQty > 0   
                  BEGIN      
                  	
                   	 IF @c_uom = '1'  -- Full pallet
                  	 BEGIN
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100
                        SELECT @b_break = '1'
                        SELECT @c_remark = 'MAX'
                  	    BREAK
                  	 END

                     IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) <= @n_MaxWeight AND      
                        @n_CumCube   + ( @n_CurQty * @n_STDCube )     <= @n_MaxCube          
                     BEGIN      
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100

                        IF @b_break = '0'
                        BEGIN
                           BEGIN TRAN
                           IF ( ( SELECT COUNT(RowId) FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID ) > 0 )
                              UPDATE #TEMPXDPARTIALPLT SET CumWeight = @n_CumWeight, CumCube = @n_CumCube
                              WHERE DropId = @c_DropID                                                      
                           ELSE                       
                              INSERT INTO #TEMPXDPARTIALPLT (DropId, Consigneekey, DeliveryDate, Col1, CumWeight, CumCube)
                                                       VALUES (@c_DropID, @c_ConsigneeKey, @d_DeliveryDate, @c_itemclass, @n_CumWeight, @n_CumCube)
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63360   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert/Update #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END  
                        
                        BREAK      
                     END      
                     ELSE      
                     BEGIN      
                     	  IF @c_uom = '2'   -- To ensure a case/inner pack not split to multi PID
                     	  BEGIN
                     	  	 SELECT @n_CurQty = @n_CurQty - @n_casecnt
                     		END                     		
                     	  ELSE
                     	  BEGIN
                     	  	 IF @c_uom = '3'
                        	 		SELECT @n_CurQty = @n_CurQty - @n_innerpack 
                        	 ELSE
                        	 		SELECT @n_CurQty = @n_CurQty - 1      
                        END

                        SELECT @b_break = '1'  -- cause split PickDetail and break Drop ID      
                        IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) > @n_MaxWeight
                        BEGIN
                           SELECT @n_Capacity = @n_CumWeight/@n_MaxWeight*100
                        END 

                        IF @n_CumCube   + ( @n_CurQty * @n_STDCube )     > @n_MaxCube
                        BEGIN
                           SELECT @n_Capacity = @n_CumCube/@n_MaxCube*100
                        END
                        SELECT @c_Remark = 'MAX'
                        
                        BEGIN TRAN                        
                        DELETE FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID
                        IF @@ERROR = 0 
                        BEGIN
                           WHILE @@TRANCOUNT > 0 
                              COMMIT TRAN 
                        END -- @@ERROR = 0 	
                        ELSE
                        BEGIN 
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63361   
            	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                        END  -- @@ERROR <> 0 

                     END      
                  END       
               
                  IF @c_debug = '1'      
                  BEGIN        
                     SELECT '@n_CurQty', @n_CurQty       
                     SELECT '@n_CumWeight', @n_CumWeight       
                     SELECT '@n_CumCube', @n_CumCube            
                  END   
               
                  IF @n_CurQty > 0       
                  BEGIN      
                     IF @n_CurQty <> @n_QtyPick        
                     BEGIN      
                        BEGIN TRAN  
                        SELECT @n_SplitQty = @n_QtyPick  - @n_CurQty      
                  
                        EXECUTE nspg_GetKey      
                           'PICKDETAILKEY',      
                           10,      
                           @c_New_PICKDETAILKey OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      

                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        IF @c_debug = '1'      
                        BEGIN        
                           SELECT '@c_New_PICKDETAILKey', @c_New_PICKDETAILKey      
                        END      
                   
                        -- new pick item for remaining @n_SplitQty    
                        INSERT PICKDETAIL      
                           ( PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,       
                           DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo )      
                        SELECT @c_New_PICKDETAILKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                           '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, '9', ShipFlag, @c_pickheaderkey      
                        FROM PICKDETAIL       
                        WHERE PICKDETAILKey = @c_PICKDETAILKey          
                            
                        IF @@ERROR <> 0     
                        BEGIN     
                           ROLLBACK TRAN  
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + 
                                             ': Insert Into PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END     

			               INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku, Qty, Lot, Loc, ID, Packkey, 
                                                     PickSlipNo, UOM, DropID, ConsigneeKey, C_Company, Priority, DeliveryDate, Capacity, Remark, PrintedFlag)
			               SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, PD.Lot, PD.Loc, PD.ID, PD.Packkey, 
                               PD.PickSlipNo, PD.UOM, PD.DropID, OH.CONSIGNEEKEY, OH.C_COMPANY, OH.Priority, OH.DeliveryDate, @n_Capacity, @c_Remark, @c_PrintedFlag
			                 FROM ORDERDETAIL OD (NOLOCK), PICKDETAIL PD (NOLOCK), ORDERS OH (NOLOCK) 
			                WHERE PD.ORDERKEY = OD.ORDERKEY 
				               AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER 
                           AND OH.ORDERKEY = OD.ORDERKEY
				               AND PD.PICKDETAILKey = @c_New_PICKDETAILKey   
                     
                        IF @@ERROR <> 0 
                        BEGIN
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63302   
   		                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           BREAK  
                        END  -- @@ERROR <> 0  
             
                        -- existing DROPID carton allow qty (@n_CurQty)   , remaining qty  (@n_SplitQty) next DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,      
                            UOMQTY = CASE UOM WHEN '6' THEN @n_CurQty ELSE UOMQty END ,     
                            DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey      
  
                        IF @@ERROR <> 0       
                        BEGIN  
                           ROLLBACK TRAN     
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END  

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,
                            DropID = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey  
                     END      
                     ELSE      
                     BEGIN      
                        -- Full Pickdetail item Qty for the DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey    
    
                        IF @@ERROR <> 0       
                        BEGIN      
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END   

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set DropID   = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,     
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey       
                     END  -- @n_CurQty <> @n_QtyPick          
                  END  -- @n_CurQty > 0      
                  ELSE -- @n_CurQty = 0
                    SELECT @n_rowid1 = @n_rowid1 - 1  -- Whole pickdetail line cannot fit reculculate with new pallet id

               END  -- WHILE 1=1 
               SET ROWCOUNT 0 
               -- Generate DropID if not data found 

		      END  -- WHILE 1=1 
            DROP Table #TEMPPICK3

         END  
         ----------------------------------------------------------------------------         
         /* END @c_ConfigKey = 'PID_PG3'                                           */
         ----------------------------------------------------------------------------
         ----------------------------------------------------------------------------         
         /* @c_ConfigKey = 'PID_PG4'                                               */
         ----------------------------------------------------------------------------
         IF @c_ConfigKey = 'PID_PG4' AND @c_SValue = '1'
         BEGIN

            SELECT @c_row = '0'

            CREATE TABLE #TEMPPICK4 (
	         Rowid			    int IDENTITY(1,1),
            SKUGROUP        NVARCHAR(10),
            PickslipNo		 NVARCHAR(10) NULL)  

            INSERT INTO #TEMPPICK4 (SKUGROUP, PickslipNo) 
            SELECT SKU.SKUGROUP, MAX(PickslipNo)
            FROM #TEMPPICKDETAIL (NOLOCK)
            JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
            GROUP BY SKU.SKUGROUP
            ORDER BY SKU.SKUGROUP

            IF @c_debug = '1'      
            BEGIN      
               SELECT * FROM #TEMPPICK4 (NOLOCK)
            END

		      SELECT @n_rowid = 0 		
   	
            WHILE 1=1 
            BEGIN
			      SELECT @n_rowid = Min(rowid) 
			        FROM #TEMPPICK4 	
			       WHERE Rowid > @n_rowid

			      IF @n_rowid IS NULL OR @n_rowid = 0 BREAK				

			      Select @c_SKUGROUP = SKUGROUP,
                      @c_PickslipNo = PickslipNo
			        from #TEMPPICK4 
			       Where Rowid = @n_rowid

               IF (@c_firsttime = 'N' AND ISNULL(@c_PickslipNo, '') = '') --re-allocation use the existing pickslipno
               BEGIN
                   SELECT @c_PickSlipNo = pickheaderkey, @c_pickheaderkey = pickheaderkey
                   FROM PickHeader (NOLOCK) 
                   WHERE ExternOrderKey = @c_refkey 
                   AND Zone = 'XD'
               END

               IF ISNULL(@c_PickslipNo, '') = ''
               BEGIN
			         EXECUTE nspg_GetKey 
				         'PICKSLIP',
				         8,   
				         @c_pickheaderkey     OUTPUT,
				         @b_success   	      OUTPUT,
				         @n_err       	      OUTPUT,
				         @c_errmsg    	      OUTPUT
      				
			         IF @n_err <> 0 
			         BEGIN
				         select @n_continue = 3
				         Break 
			         END
      				
			         IF @c_type = 'P' 
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END
			         ELSE
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END  -- @c_type = 'P' 
      				
			         select @c_row = Convert(char(10), convert(int, @c_row) + 1) 

                  IF @c_debug = '1'      
                  BEGIN      
                     SELECT ' @c_pickheaderkey =' + @c_pickheaderkey 
                  END

                  BEGIN TRAN 

			         INSERT INTO PICKHEADER (PickHeaderKey,    WaveKey,    ExternOrderKey, PickType, Zone, TrafficCop)
			         VALUES (@c_pickheaderkey, @c_row, @c_refkey,     '0',      'XD',  '')

                  IF @@ERROR = 0 
                  BEGIN
                     WHILE @@TRANCOUNT > 0 
                        COMMIT TRAN 
                  END 	
                  ELSE
                  BEGIN
                     ROLLBACK TRAN 
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63315   
      		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PickHeader Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                     BREAK 
                  END  -- @@ERROR = 0 

                  IF @n_continue = 1 OR @n_continue = 2  
                  BEGIN
				         BEGIN TRAN 

                     UPDATE #TEMPPICKDETAIL 
                        SET PICKSLIPNO = @c_pickheaderkey 
                        FROM  #TEMPPICKDETAIL
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
                                               AND SKU.SKUGROUP = @c_SKUGROUP  
                                                     	
				         SELECT @n_err = @@ERROR
      			
                     IF @n_err = 0 
                     BEGIN
                        WHILE @@TRANCOUNT > 0 
                           COMMIT TRAN 
                     END 	
                     ELSE
                     BEGIN
                        ROLLBACK TRAN 
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63316   
         		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
					         Break
                     END  -- @n_err = 0 

                     IF @c_debug = '1'      
                     BEGIN      
                        SELECT PICKSLIPNO
                        FROM #TEMPPICKDETAIL 
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU )
                                               AND SKU.SKUGROUP = @c_SKUGROUP  
                     END

                  END  -- @n_continue = 1 OR @n_continue = 2
               END  -- ISNULL(@c_PickslipNo, '') = ''
               ELSE
                  SELECT @c_pickheaderkey = @c_PickslipNo 

               -- Generate DropID if not data found 
               SELECT @n_rowid1         = 0 
               SELECT @b_break          = '0'  
               SELECT @c_BreakKey       = ''
               SELECT @c_prev_BreakKey  = '' 
               SELECT @b_newgroup       = '0'                    

               SET ROWCOUNT 1 		
               WHILE 1=1 
               BEGIN
                  SELECT @c_PICKDETAILKey = ''
                  SELECT @c_ConsigneeKey = ''
                  SELECT @d_DeliveryDate = ''  
                  SELECT @c_sku = ''  
                  SELECT @n_StdGrossWGT = ''  
                  SELECT @n_STDCube = ''  
                  SELECT @n_QtyPick = 0 
                  SELECT @c_CartonType = '' 
                  SELECT @n_MaxWeight = '' 
                  SELECT @n_MaxCube = '' 
	                SELECT @n_casecnt = 0      
                  SELECT @n_innerpack = 0               
                  SELECT @c_uom = ''

                  SELECT @n_rowid1        = #TEMPPICKDETAIL.rowid, 
                         @c_PICKDETAILKey = #TEMPPICKDETAIL.PICKDETAILKey, 
                         @c_ConsigneeKey  = #TEMPPICKDETAIL.ConsigneeKey,
                         @d_DeliveryDate  = #TEMPPICKDETAIL.DeliveryDate,
                         @c_sku           = SKU.SKU,      
                         @n_StdGrossWGT   = ISNULL(SKU.StdGrossWGT,0),           
                         @n_STDCube       = ISNULL(SKU.STDCube,0),      
                         @n_QtyPick       = ISNULL(#TEMPPICKDETAIL.Qty,0), 
                         @c_CartonType    = Cartonization.CartonType,
                         @n_MaxWeight     = ISNULL(Cartonization.MaxWeight,0),      
                         @n_MaxCube       = ISNULL(Cartonization.[Cube],0),          
                         @n_CaseCnt       = PACK.casecnt,
                         @n_Innerpack     = PACK.innerpack,
                         @c_uom           = #TEMPPICKDETAIL.uom
                  FROM #TEMPPICKDETAIL (NOLOCK)
                  JOIN SKU     (NOLOCK) ON ( #TEMPPICKDETAIL.Storerkey = SKU.StorerKey ) 
                                             AND ( #TEMPPICKDETAIL.Sku = SKU.Sku )
                  JOIN Storer (NOLOCK) on ( Storer.StorerKey = #TEMPPICKDETAIL.StorerKey )      
                  JOIN Cartonization (NOLOCK) on ( Cartonization.CartonizationGroup = Storer.CartonGroup )  
                                             AND ( Cartonization.CartonType = CASE #TEMPPICKDETAIL.UOM WHEN '1' THEN 'Pallet' WHEN '2' THEN 'Pallet' ELSE 'Tote' END )  
                  JOIN Pack (NOLOCK) ON ( #TEMPPICKDETAIL.Packkey = Pack.Packkey)
	               Where ISNULL(#TEMPPICKDETAIL.Qty,0) > 0      
                  AND   LEN(ISNULL(#TEMPPICKDETAIL.DropID, '')) = 0       
                  AND   SKU.StdGrossWGT <= Cartonization.MaxWeight    -- Not process for wrong setup,  cartonization weight/cube is less then SKU QTY 1     
                  AND   SKU.STDCube <=  Cartonization.[Cube]  
                  AND   (SKU.StdGrossWGT * PACK.casecnt) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.casecnt) <= Cartonization.[Cube]
                  AND   (SKU.StdGrossWGT * PACK.innerpack) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.innerpack) <= Cartonization.[Cube]
                  AND   #TEMPPICKDETAIL.Rowid > @n_rowid1
                  AND   SKU.SKUGROUP = @c_SKUGROUP
                  Order by #TEMPPICKDETAIL.rowid

	               IF ISNULL(RTRIM(@n_rowid1), 0) = 0 OR ISNULL(RTRIM(@c_ConsigneeKey), '') = ''
                  BEGIN
                     BREAK	
                  END			

                  SELECT @c_BreakKey = ISNULL(RTRIM(@c_ConsigneeKey), '') +'/'+ ISNULL(RTRIM(@d_DeliveryDate), '') 

                  IF @c_debug = '1'      
                  BEGIN         
                     SELECT '@c_prev_BreakKey', @c_prev_BreakKey, '@c_BreakKey', @c_BreakKey      
                  END 

                  IF @c_BreakKey <> @c_prev_BreakKey      
                  BEGIN      
                     SELECT @c_prev_breakkey = @c_breakkey      
                     Select @b_break = '1'      
                     SELECT @b_newgroup = '1'      
                  END    

                  -- break DropID      
                  IF  @b_break = '1' 
                  BEGIN 
                     IF @c_debug = '1'      
                     BEGIN        
                        SELECT '@c_CartonType', @c_CartonType       
                        SELECT '@n_MaxWeight', @n_MaxWeight, '@n_MaxCube', @n_MaxCube    
                     END      
                     SELECT @b_getdropid = '1'
                     IF @b_newgroup = '1' and @c_uom <> '1'
                     BEGIN
             	         	BEGIN TRAN               
									      INSERT INTO XDPartialPlt (DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7,
                                 									Col8, Col9, Col10, CumWeight, CumCube)
         								SELECT DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7, 
                							Col8, Col9, Col10, CumWeight, CumCube
	         							FROM #TEMPXDPARTIALPLT
                              
					  		        IF @@ERROR = 0 
    		   							BEGIN
              						WHILE @@TRANCOUNT > 0 
                								COMMIT TRAN 
                				  DELETE FROM #TEMPXDPARTIALPLT
         				    		END -- @@ERROR = 0 	
         							  ELSE
         							  BEGIN 
            						  ROLLBACK TRAN 
            						  SELECT @n_continue = 3
            						  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63353   
          							  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         								END  -- @@ERROR <> 0 
                     	
                        SELECT @n_RowId2 = a.Rowid, @c_DropID = a.DropId, @n_CumWeight = a.CumWeight, @n_CumCube = a.CumCube
                        FROM XDPartialPlt a (NOLOCK), pickdetail b (NOLOCK)
                        WHERE a.Consigneekey = @c_ConsigneeKey
                        AND CONVERT(char(8),a.DeliveryDate,1) = CONVERT(char(8),@d_DeliveryDate,1)
                        AND a.Col1 = @c_SKUGROUP  
                        AND a.DropId = b.DropId
                        
                        IF @@ROWCOUNT > 0
                        BEGIN
                           SELECT @b_getdropid = '0'
                          
                           BEGIN TRAN
                           DELETE FROM XDPartialPlt WHERE RowId = @n_RowId2
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63361   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END

                        SELECT @b_newgroup = '0'
                     END
                     
                     IF @b_getdropid = '1'
                     BEGIN               
                        EXECUTE nspg_GetKey      
                           'PICKToID',      
                           10,      
                           @c_DropID OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      
   
                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        SELECT @n_CumWeight = 0      
                        SELECT @n_CumCube   = 0        
                     END  
                     SELECT @n_CurQty    = 0    
                     SELECT @n_CapWeight = 0          
                     SELECT @n_CapCube   = 0  
                     SELECT @c_Remark    = ''  
                     SELECT @b_break     = '0'  
                  END

                  SELECT @n_SplitQty = 0      
                  SELECT @n_CurQty   = @n_QtyPick  

                  -- loop decs to fit in Pallet\Tote Weight\Cube      
                  WHILE @n_CurQty > 0      
                  BEGIN      

                   	 IF @c_uom = '1'  -- Full pallet
                  	 BEGIN
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100
                        SELECT @b_break = '1'
                        SELECT @c_remark = 'MAX'
                  	    BREAK
                  	 END

                     IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) <= @n_MaxWeight AND      
                        @n_CumCube   + ( @n_CurQty * @n_STDCube )     <= @n_MaxCube          
                     BEGIN      
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100

                        IF @b_break = '0'
                        BEGIN
                           BEGIN TRAN
                           IF ( ( SELECT COUNT(RowId) FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID ) > 0 )
                              UPDATE #TEMPXDPARTIALPLT SET CumWeight = @n_CumWeight, CumCube = @n_CumCube
                              WHERE DropId = @c_DropID                                                      
                           ELSE                       
                              INSERT INTO #TEMPXDPARTIALPLT (DropId, Consigneekey, DeliveryDate, Col1, CumWeight, CumCube)
                                                       VALUES (@c_DropID, @c_ConsigneeKey, @d_DeliveryDate, @c_SKUGROUP, @n_CumWeight, @n_CumCube)
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63362   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert/Update #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END  
                        
                        BREAK      
                     END      
                     ELSE      
                     BEGIN      
                     	  IF @c_uom = '2'   -- To ensure a case/inner pack not split to multi PID
                     	  BEGIN
                     	  	 SELECT @n_CurQty = @n_CurQty - @n_casecnt
                     		END                     		
                     	  ELSE
                     	  BEGIN
                     	  	 IF @c_uom = '3'
                        	 		SELECT @n_CurQty = @n_CurQty - @n_innerpack 
                        	 ELSE
                        	 		SELECT @n_CurQty = @n_CurQty - 1      
                        END

                        SELECT @b_break = '1'  -- cause split PickDetail and break Drop ID      
                        IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) > @n_MaxWeight
                        BEGIN
                           SELECT @n_Capacity = @n_CumWeight/@n_MaxWeight*100
                        END 

                        IF @n_CumCube   + ( @n_CurQty * @n_STDCube )     > @n_MaxCube
                        BEGIN
                           SELECT @n_Capacity = @n_CumCube/@n_MaxCube*100
                        END
                        SELECT @c_Remark = 'MAX'
                        
                        BEGIN TRAN                        
                        DELETE FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID
                        IF @@ERROR = 0 
                        BEGIN
                           WHILE @@TRANCOUNT > 0 
                              COMMIT TRAN 
                        END -- @@ERROR = 0 	
                        ELSE
                        BEGIN 
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63363   
            	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                        END  -- @@ERROR <> 0 

                     END      
                  END       
               
                  IF @c_debug = '1'      
                  BEGIN        
                     SELECT '@n_CurQty', @n_CurQty       
                     SELECT '@n_CumWeight', @n_CumWeight       
                     SELECT '@n_CumCube', @n_CumCube            
                  END   
               
                  IF @n_CurQty > 0       
                  BEGIN      
                     IF @n_CurQty <> @n_QtyPick        
                     BEGIN      
                        BEGIN TRAN  
                        SELECT @n_SplitQty = @n_QtyPick  - @n_CurQty      
                  
                        EXECUTE nspg_GetKey      
                           'PICKDETAILKEY',      
                           10,      
                           @c_New_PICKDETAILKey OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      

                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        IF @c_debug = '1'      
                        BEGIN        
                           SELECT '@c_New_PICKDETAILKey', @c_New_PICKDETAILKey      
                        END      
                   
                        -- new pick item for remaining @n_SplitQty    
                        INSERT PICKDETAIL      
                           ( PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,       
                           DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo )      
                        SELECT @c_New_PICKDETAILKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                           '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, '9', ShipFlag, @c_pickheaderkey      
                        FROM PICKDETAIL       
                        WHERE PICKDETAILKey = @c_PICKDETAILKey          
                            
                        IF @@ERROR <> 0     
                        BEGIN     
                           ROLLBACK TRAN  
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + 
                                             ': Insert Into PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END     

			               INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku, Qty, Lot, Loc, ID, Packkey, 
                                                     PickSlipNo, UOM, DropID, ConsigneeKey, C_Company, Priority, DeliveryDate, Capacity, Remark, PrintedFlag)
			               SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, PD.Lot, PD.Loc, PD.ID, PD.Packkey, 
                               PD.PickSlipNo, PD.UOM, PD.DropID, OH.CONSIGNEEKEY, OH.C_COMPANY, OH.Priority, OH.DeliveryDate, @n_Capacity, @c_Remark, @c_PrintedFlag
			                 FROM ORDERDETAIL OD (NOLOCK), PICKDETAIL PD (NOLOCK), ORDERS OH (NOLOCK) 
			                WHERE PD.ORDERKEY = OD.ORDERKEY 
				               AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER 
                           AND OH.ORDERKEY = OD.ORDERKEY
				               AND PD.PICKDETAILKey = @c_New_PICKDETAILKey   
                     
                        IF @@ERROR <> 0 
                        BEGIN
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63302   
   		                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           BREAK  
                        END  -- @@ERROR <> 0  
             
                        -- existing DROPID carton allow qty (@n_CurQty)   , remaining qty  (@n_SplitQty) next DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,      
                            UOMQTY = CASE UOM WHEN '6' THEN @n_CurQty ELSE UOMQty END ,     
                            DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey      
  
                        IF @@ERROR <> 0       
                        BEGIN  
                           ROLLBACK TRAN     
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END  

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,
                            DropID = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey  
                     END      
                     ELSE      
                     BEGIN      
                        -- Full Pickdetail item Qty for the DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey    
    
                        IF @@ERROR <> 0       
                        BEGIN      
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END   

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set DropID   = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,    
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey       
                     END  -- @n_CurQty <> @n_QtyPick          
                  END  -- @n_CurQty > 0      
                  ELSE -- @n_CurQty = 0
                    SELECT @n_rowid1 = @n_rowid1 - 1  -- Whole pickdetail line cannot fit reculculate with new pallet id

               END  -- WHILE 1=1 
               SET ROWCOUNT 0 
               -- Generate DropID if not data found 

		      END  -- WHILE 1=1 
            DROP Table #TEMPPICK4

         END  
         ----------------------------------------------------------------------------         
         /* END @c_ConfigKey = 'PID_PG4'                                           */
         ----------------------------------------------------------------------------
         ----------------------------------------------------------------------------         
         /* @c_ConfigKey = 'PID_PG5'                                               */
         ----------------------------------------------------------------------------
         IF @c_ConfigKey = 'PID_PG5' AND @c_SValue = '1'
         BEGIN

            SELECT @c_row = '0'

            CREATE TABLE #TEMPPICK5 (
	         Rowid			    int IDENTITY(1,1),
            Style           NVARCHAR(20),
            PickslipNo		 NVARCHAR(10) NULL)  

            INSERT INTO #TEMPPICK5 (Style, PickslipNo) 
            SELECT SKU.Style, MAX(PickslipNo)
            FROM #TEMPPICKDETAIL (NOLOCK)
            JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
            GROUP BY SKU.Style
            ORDER BY SKU.Style

            IF @c_debug = '1'      
            BEGIN      
               SELECT * FROM #TEMPPICK5 (NOLOCK)
            END

		      SELECT @n_rowid = 0 		
   	
            WHILE 1=1 
            BEGIN
			      SELECT @n_rowid = Min(rowid) 
			        FROM #TEMPPICK5 	
			       WHERE Rowid > @n_rowid

			      IF @n_rowid IS NULL OR @n_rowid = 0 BREAK				

			      Select @c_Style = Style,
                      @c_PickslipNo = PickslipNo 
			        from #TEMPPICK5 
			       Where Rowid = @n_rowid

               IF (@c_firsttime = 'N' AND ISNULL(@c_PickslipNo, '') = '') --re-allocation use the existing pickslipno
               BEGIN
                   SELECT @c_PickSlipNo = pickheaderkey, @c_pickheaderkey = pickheaderkey
                   FROM PickHeader (NOLOCK) 
                   WHERE ExternOrderKey = @c_refkey 
                   AND Zone = 'XD'
               END

               IF ISNULL(@c_PickslipNo, '') = ''
               BEGIN
			         EXECUTE nspg_GetKey 
				         'PICKSLIP',
				         8,   
				         @c_pickheaderkey     OUTPUT,
				         @b_success   	      OUTPUT,
				         @n_err       	      OUTPUT,
				         @c_errmsg    	      OUTPUT
      				
			         IF @n_err <> 0 
			         BEGIN
				         select @n_continue = 3
				         Break 
			         END
      				
			         IF @c_type = 'P' 
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END
			         ELSE
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END  -- @c_type = 'P' 
      				
			         select @c_row = Convert(char(10), convert(int, @c_row) + 1) 

                  IF @c_debug = '1'      
                  BEGIN      
                     SELECT ' @c_pickheaderkey =' + @c_pickheaderkey 
                  END

                  BEGIN TRAN 

			         INSERT INTO PICKHEADER (PickHeaderKey,    WaveKey,    ExternOrderKey, PickType, Zone, TrafficCop)
			         VALUES (@c_pickheaderkey, @c_row, @c_refkey,     '0',      'XD',  '')

                  IF @@ERROR = 0 
                  BEGIN
                     WHILE @@TRANCOUNT > 0 
                        COMMIT TRAN 
                  END 	
                  ELSE
                  BEGIN
                     ROLLBACK TRAN 
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63317   
      		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PickHeader Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                     BREAK 
                  END  -- @@ERROR = 0 

                  IF @n_continue = 1 OR @n_continue = 2  
                  BEGIN
				         BEGIN TRAN 

                     UPDATE #TEMPPICKDETAIL 
                        SET PICKSLIPNO = @c_pickheaderkey 
                        FROM  #TEMPPICKDETAIL
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU )
                                               AND SKU.Style = @c_Style         	
				         SELECT @n_err = @@ERROR
      			
                     IF @n_err = 0 
                     BEGIN
                        WHILE @@TRANCOUNT > 0 
                           COMMIT TRAN 
                     END 	
                     ELSE
                     BEGIN
                        ROLLBACK TRAN 
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63318   
         		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
					         Break
                     END  -- @n_err = 0 

                     IF @c_debug = '1'      
                     BEGIN      
                        SELECT PICKSLIPNO
                        FROM #TEMPPICKDETAIL 
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
                                               AND SKU.Style = @c_Style 
                     END

                  END  -- @n_continue = 1 OR @n_continue = 2
               END  -- ISNULL(@c_PickslipNo, '') = ''
               ELSE
                  SELECT @c_pickheaderkey = @c_PickslipNo 

               -- Generate DropID if not data found 
               SELECT @n_rowid1         = 0 
               SELECT @b_break          = '0'  
               SELECT @c_BreakKey       = ''
               SELECT @c_prev_BreakKey  = ''               
               SELECT @b_newgroup       = '0'                     

               SET ROWCOUNT 1 		
               WHILE 1=1 
               BEGIN
                  SELECT @c_PICKDETAILKey = ''
                  SELECT @c_ConsigneeKey = ''
                  SELECT @d_DeliveryDate = ''  
                  SELECT @c_sku = ''  
                  SELECT @n_StdGrossWGT = ''  
                  SELECT @n_STDCube = ''  
                  SELECT @n_QtyPick = 0 
                  SELECT @c_CartonType = '' 
                  SELECT @n_MaxWeight = '' 
                  SELECT @n_MaxCube = '' 
	                SELECT @n_casecnt = 0      
                  SELECT @n_innerpack = 0               
                  SELECT @c_uom = ''

                  SELECT @n_rowid1        = #TEMPPICKDETAIL.rowid, 
                         @c_PICKDETAILKey = #TEMPPICKDETAIL.PICKDETAILKey, 
                         @c_ConsigneeKey  = #TEMPPICKDETAIL.ConsigneeKey,
                         @d_DeliveryDate  = #TEMPPICKDETAIL.DeliveryDate,
                         @c_sku           = SKU.SKU,      
                         @n_StdGrossWGT   = ISNULL(SKU.StdGrossWGT,0),           
                         @n_STDCube       = ISNULL(SKU.STDCube,0),      
                         @n_QtyPick       = ISNULL(#TEMPPICKDETAIL.Qty,0), 
                         @c_CartonType    = Cartonization.CartonType,
                         @n_MaxWeight     = ISNULL(Cartonization.MaxWeight,0),      
                         @n_MaxCube       = ISNULL(Cartonization.[Cube],0),          
                         @n_CaseCnt       = PACK.casecnt,
                         @n_Innerpack     = PACK.innerpack,
                         @c_uom           = #TEMPPICKDETAIL.uom
                  FROM #TEMPPICKDETAIL (NOLOCK)
                  JOIN SKU     (NOLOCK) ON ( #TEMPPICKDETAIL.Storerkey = SKU.StorerKey ) 
                                             AND ( #TEMPPICKDETAIL.Sku = SKU.Sku )
                  JOIN Storer (NOLOCK) on ( Storer.StorerKey = #TEMPPICKDETAIL.StorerKey )      
                  JOIN Cartonization (NOLOCK) on ( Cartonization.CartonizationGroup = Storer.CartonGroup )  
                                             AND ( Cartonization.CartonType = CASE #TEMPPICKDETAIL.UOM WHEN '1' THEN 'Pallet' WHEN '2' THEN 'Pallet' ELSE 'Tote' END )  
                  JOIN Pack (NOLOCK) ON ( #TEMPPICKDETAIL.Packkey = Pack.Packkey)
	               Where ISNULL(#TEMPPICKDETAIL.Qty,0) > 0      
                  AND   LEN(ISNULL(#TEMPPICKDETAIL.DropID, '')) = 0       
                  AND   SKU.StdGrossWGT <= Cartonization.MaxWeight    -- Not process for wrong setup,  cartonization weight/cube is less then SKU QTY 1     
                  AND   SKU.STDCube <=  Cartonization.[Cube]  
                  AND   (SKU.StdGrossWGT * PACK.casecnt) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.casecnt) <= Cartonization.[Cube]
                  AND   (SKU.StdGrossWGT * PACK.innerpack) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.innerpack) <= Cartonization.[Cube]
                  AND   #TEMPPICKDETAIL.Rowid > @n_rowid1
                  AND   SKU.Style = @c_Style 
                  Order by #TEMPPICKDETAIL.rowid

	               IF ISNULL(RTRIM(@n_rowid1), 0) = 0 OR ISNULL(RTRIM(@c_ConsigneeKey), '') = ''
                  BEGIN
                     BREAK	
                  END			

                  SELECT @c_BreakKey = ISNULL(RTRIM(@c_ConsigneeKey), '') +'/'+ ISNULL(RTRIM(@d_DeliveryDate), '') 

                  IF @c_debug = '1'      
                  BEGIN         
                     SELECT '@c_prev_BreakKey', @c_prev_BreakKey, '@c_BreakKey', @c_BreakKey      
                  END 

                  IF @c_BreakKey <> @c_prev_BreakKey      
                  BEGIN      
                     SELECT @c_prev_breakkey = @c_breakkey      
                     Select @b_break = '1'      
                     SELECT @b_newgroup = '1'      
                  END    

                  -- break DropID      
                  IF  @b_break = '1' 
                  BEGIN 
                     IF @c_debug = '1'      
                     BEGIN        
                        SELECT '@c_CartonType', @c_CartonType       
                        SELECT '@n_MaxWeight', @n_MaxWeight, '@n_MaxCube', @n_MaxCube    
                     END      
                     SELECT @b_getdropid = '1'
                     IF @b_newgroup = '1' and @c_uom <> '1'
                     BEGIN
             	         	BEGIN TRAN               
									      INSERT INTO XDPartialPlt (DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7,
                                 									Col8, Col9, Col10, CumWeight, CumCube)
         								SELECT DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7, 
                							Col8, Col9, Col10, CumWeight, CumCube
	         							FROM #TEMPXDPARTIALPLT
                              
					  		        IF @@ERROR = 0 
    		   							BEGIN
              						WHILE @@TRANCOUNT > 0 
                								COMMIT TRAN 
                				  DELETE FROM #TEMPXDPARTIALPLT
         				    		END -- @@ERROR = 0 	
         							  ELSE
         							  BEGIN 
            						  ROLLBACK TRAN 
            						  SELECT @n_continue = 3
            						  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63353   
          							  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         								END  -- @@ERROR <> 0 
                     	
                        SELECT @n_RowId2 = a.Rowid, @c_DropID = a.DropId, @n_CumWeight = a.CumWeight, @n_CumCube = a.CumCube
                        FROM XDPartialPlt a (NOLOCK), pickdetail b (NOLOCK)
                        WHERE a.Consigneekey = @c_ConsigneeKey
                        AND CONVERT(char(8),a.DeliveryDate,1) = CONVERT(char(8),@d_DeliveryDate,1)
                        AND a.Col1 = @c_Style 
                        AND a.DropId = b.DropId
                        
                        IF @@ROWCOUNT > 0
                        BEGIN
                           SELECT @b_getdropid = '0'
                          
                           BEGIN TRAN
                           DELETE FROM XDPartialPlt WHERE RowId = @n_RowId2
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63364   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END

                        SELECT @b_newgroup = '0'
                     END
                     
                     IF @b_getdropid = '1'
                     BEGIN               
                        EXECUTE nspg_GetKey      
                           'PICKToID',      
                           10,      
                           @c_DropID OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      
   
                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        SELECT @n_CumWeight = 0      
                        SELECT @n_CumCube   = 0 
                     END         
                     SELECT @n_CurQty    = 0    
                     SELECT @n_CapWeight = 0          
                     SELECT @n_CapCube   = 0  
                     SELECT @c_Remark    = ''  
                     SELECT @b_break     = '0'  
                  END

                  SELECT @n_SplitQty = 0      
                  SELECT @n_CurQty   = @n_QtyPick  

                  -- loop decs to fit in Pallet\Tote Weight\Cube      
                  WHILE @n_CurQty > 0      
                  BEGIN      
                  	
                   	 IF @c_uom = '1'  -- Full pallet
                  	 BEGIN
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100
                        SELECT @b_break = '1'
                        SELECT @c_remark = 'MAX'
                  	    BREAK
                  	 END
                  	
                     IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) <= @n_MaxWeight AND      
                        @n_CumCube   + ( @n_CurQty * @n_STDCube )     <= @n_MaxCube          
                     BEGIN      
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100

                        IF @b_break = '0'
                        BEGIN                        
                           BEGIN TRAN
                           IF ( ( SELECT COUNT(RowId) FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID ) > 0 )
                              UPDATE #TEMPXDPARTIALPLT SET CumWeight = @n_CumWeight, CumCube = @n_CumCube
                              WHERE DropId = @c_DropID                                                      
                           ELSE                       
                              INSERT INTO #TEMPXDPARTIALPLT (DropId, Consigneekey, DeliveryDate, Col1, CumWeight, CumCube)
                                                       VALUES (@c_DropID, @c_ConsigneeKey, @d_DeliveryDate, @c_Style, @n_CumWeight, @n_CumCube)
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63365   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert/Update #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END

                        BREAK      
                     END      
                     ELSE      
                     BEGIN      
                     	  IF @c_uom = '2'   -- To ensure a case/inner pack not split to multi PID
                     	  BEGIN
                     	  	 SELECT @n_CurQty = @n_CurQty - @n_casecnt
                     		END                     		
                     	  ELSE
                     	  BEGIN
                     	  	 IF @c_uom = '3'
                        	 		SELECT @n_CurQty = @n_CurQty - @n_innerpack 
                        	 ELSE
                        	 		SELECT @n_CurQty = @n_CurQty - 1      
                        END

                        SELECT @b_break = '1'  -- cause split PickDetail and break Drop ID      
                        IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) > @n_MaxWeight
                        BEGIN
                           SELECT @n_Capacity = @n_CumWeight/@n_MaxWeight*100
                        END 

                        IF @n_CumCube   + ( @n_CurQty * @n_STDCube )     > @n_MaxCube
                        BEGIN
                           SELECT @n_Capacity = @n_CumCube/@n_MaxCube*100
                        END
                        SELECT @c_Remark = 'MAX'
                        
                        BEGIN TRAN                        
                        DELETE FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID
                        IF @@ERROR = 0 
                        BEGIN
                           WHILE @@TRANCOUNT > 0 
                              COMMIT TRAN 
                        END -- @@ERROR = 0 	
                        ELSE
                        BEGIN 
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63366   
            	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                        END  -- @@ERROR <> 0 

                     END      
                  END       
               
                  IF @c_debug = '1'      
                  BEGIN        
                     SELECT '@n_CurQty', @n_CurQty       
                     SELECT '@n_CumWeight', @n_CumWeight       
                     SELECT '@n_CumCube', @n_CumCube            
                  END   
               
                  IF @n_CurQty > 0       
                  BEGIN      
                     IF @n_CurQty <> @n_QtyPick        
                     BEGIN      
                        BEGIN TRAN  
                        SELECT @n_SplitQty = @n_QtyPick  - @n_CurQty      
                  
                        EXECUTE nspg_GetKey      
                           'PICKDETAILKEY',      
                           10,      
                           @c_New_PICKDETAILKey OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      

                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        IF @c_debug = '1'      
                        BEGIN        
                           SELECT '@c_New_PICKDETAILKey', @c_New_PICKDETAILKey      
                        END      
                   
                        -- new pick item for remaining @n_SplitQty    
                        INSERT PICKDETAIL      
                           ( PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,       
                           DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo )      
                        SELECT @c_New_PICKDETAILKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                           '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, '9', ShipFlag, @c_pickheaderkey      
                        FROM PICKDETAIL       
                        WHERE PICKDETAILKey = @c_PICKDETAILKey          
                            
                        IF @@ERROR <> 0     
                        BEGIN     
                           ROLLBACK TRAN  
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + 
                                             ': Insert Into PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END     

			               INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku, Qty, Lot, Loc, ID, Packkey, 
                                                     PickSlipNo, UOM, DropID, ConsigneeKey, C_Company, Priority, DeliveryDate, Capacity, Remark, PrintedFlag)
			               SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, PD.Lot, PD.Loc, PD.ID, PD.Packkey, 
                               PD.PickSlipNo, PD.UOM, PD.DropID, OH.CONSIGNEEKEY, OH.C_COMPANY, OH.Priority, OH.DeliveryDate, @n_Capacity, @c_Remark, @c_PrintedFlag
			                 FROM ORDERDETAIL OD (NOLOCK), PICKDETAIL PD (NOLOCK), ORDERS OH (NOLOCK) 
			                WHERE PD.ORDERKEY = OD.ORDERKEY 
				               AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER 
                           AND OH.ORDERKEY = OD.ORDERKEY
				               AND PD.PICKDETAILKey = @c_New_PICKDETAILKey   
                     
                        IF @@ERROR <> 0 
                        BEGIN
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63302   
   		                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           BREAK  
                        END  -- @@ERROR <> 0  
             
                        -- existing DROPID carton allow qty (@n_CurQty)   , remaining qty  (@n_SplitQty) next DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,      
                            UOMQTY = CASE UOM WHEN '6' THEN @n_CurQty ELSE UOMQty END ,     
                            DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey      
  
                        IF @@ERROR <> 0       
                        BEGIN  
                           ROLLBACK TRAN     
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END  

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,
                            DropID = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey  
                     END      
                     ELSE      
                     BEGIN      
                        -- Full Pickdetail item Qty for the DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey    
    
                        IF @@ERROR <> 0       
                        BEGIN      
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END   

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set DropID   = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,     
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey       
                     END  -- @n_CurQty <> @n_QtyPick          
                  END  -- @n_CurQty > 0      
                  ELSE -- @n_CurQty = 0
                    SELECT @n_rowid1 = @n_rowid1 - 1  -- Whole pickdetail line cannot fit reculculate with new pallet id

               END  -- WHILE 1=1 
               SET ROWCOUNT 0 
               -- Generate DropID if not data found 

		      END  -- WHILE 1=1 
            DROP Table #TEMPPICK5

         END  
         ----------------------------------------------------------------------------         
         /* END @c_ConfigKey = 'PID_PG5'                                           */
         ----------------------------------------------------------------------------
         ----------------------------------------------------------------------------         
         /* @c_ConfigKey = 'PID_PG6'                                               */
         ----------------------------------------------------------------------------
         IF @c_ConfigKey = 'PID_PG6' AND @c_SValue = '1'
         BEGIN

            SELECT @c_row = '0'

            CREATE TABLE #TEMPPICK6 (
	         Rowid			    int IDENTITY(1,1),
            Color           NVARCHAR(10),
            PickslipNo		 NVARCHAR(10) NULL)  

            INSERT INTO #TEMPPICK6 (Color, PickslipNo) 
            SELECT SKU.Color, MAX(PickslipNo)
            FROM #TEMPPICKDETAIL (NOLOCK)
            JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
            GROUP BY SKU.Color
            ORDER BY SKU.Color

            IF @c_debug = '1'      
            BEGIN      
               SELECT * FROM #TEMPPICK6 (NOLOCK)
            END

		      SELECT @n_rowid = 0 		
   	
            WHILE 1=1 
            BEGIN
			      SELECT @n_rowid = Min(rowid) 
			        FROM #TEMPPICK6 	
			       WHERE Rowid > @n_rowid

			      IF @n_rowid IS NULL OR @n_rowid = 0 BREAK				

			      Select @c_Color = Color,
                      @c_PickslipNo = PickslipNo 
			        from #TEMPPICK6 
			       Where Rowid = @n_rowid

               IF (@c_firsttime = 'N' AND ISNULL(@c_PickslipNo, '') = '') --re-allocation use the existing pickslipno
               BEGIN
                   SELECT @c_PickSlipNo = pickheaderkey, @c_pickheaderkey = pickheaderkey
                   FROM PickHeader (NOLOCK) 
                   WHERE ExternOrderKey = @c_refkey 
                   AND Zone = 'XD'
               END

               IF ISNULL(@c_PickslipNo, '') = ''               
               BEGIN
			         EXECUTE nspg_GetKey 
				         'PICKSLIP',
				         8,   
				         @c_pickheaderkey     OUTPUT,
				         @b_success   	      OUTPUT,
				         @n_err       	      OUTPUT,
				         @c_errmsg    	      OUTPUT
      				
			         IF @n_err <> 0 
			         BEGIN
				         select @n_continue = 3
				         Break 
			         END
      				
			         IF @c_type = 'P' 
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END
			         ELSE
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END  -- @c_type = 'P' 
      				
			         select @c_row = Convert(char(10), convert(int, @c_row) + 1) 

                  IF @c_debug = '1'      
                  BEGIN      
                     SELECT '@c_pickheaderkey =' + @c_pickheaderkey 
                  END

                  BEGIN TRAN 

			         INSERT INTO PICKHEADER (PickHeaderKey,    WaveKey,    ExternOrderKey, PickType, Zone, TrafficCop)
			         VALUES (@c_pickheaderkey, @c_row, @c_refkey,     '0',      'XD',  '')

                  IF @@ERROR = 0 
                  BEGIN
                     WHILE @@TRANCOUNT > 0 
                        COMMIT TRAN 
                  END 	
                  ELSE
                  BEGIN
                     ROLLBACK TRAN 
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63319   
      		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PickHeader Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                     BREAK 
                  END  -- @@ERROR = 0 

                  IF @n_continue = 1 OR @n_continue = 2  
                  BEGIN
				         BEGIN TRAN 

                     UPDATE #TEMPPICKDETAIL 
                        SET PICKSLIPNO = @c_pickheaderkey 
                        FROM  #TEMPPICKDETAIL
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU )
                                               AND SKU.Color = @c_Color      	
				         SELECT @n_err = @@ERROR
      			
                     IF @n_err = 0 
                     BEGIN
                        WHILE @@TRANCOUNT > 0 
                           COMMIT TRAN 
                     END 	
                     ELSE
                     BEGIN
                        ROLLBACK TRAN 
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63320   
         		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
					         Break
                     END  -- @n_err = 0 

                     IF @c_debug = '1'      
                     BEGIN      
                        SELECT PICKSLIPNO
                        FROM #TEMPPICKDETAIL 
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
                                               AND SKU.Color = @c_Color 
                     END

                  END  -- @n_continue = 1 OR @n_continue = 2
               END  -- ISNULL(@c_PickslipNo, '') = ''
               ELSE
                  SELECT @c_pickheaderkey = @c_PickslipNo 

               -- Generate DropID if not data found 
               SELECT @n_rowid1         = 0 
               SELECT @b_break          = '0'  
               SELECT @c_BreakKey       = ''
               SELECT @c_prev_BreakKey  = ''   
               SELECT @b_newgroup       = '0'      
                           
               SET ROWCOUNT 1 		
               WHILE 1=1 
               BEGIN
                  SELECT @c_PICKDETAILKey = ''
                  SELECT @c_ConsigneeKey = ''
                  SELECT @d_DeliveryDate = ''  
                  SELECT @c_sku = ''  
                  SELECT @n_StdGrossWGT = ''  
                  SELECT @n_STDCube = ''  
                  SELECT @n_QtyPick = 0 
                  SELECT @c_CartonType = '' 
                  SELECT @n_MaxWeight = '' 
                  SELECT @n_MaxCube = '' 
	                SELECT @n_casecnt = 0      
                  SELECT @n_innerpack = 0               
                  SELECT @c_uom = ''

                  SELECT @n_rowid1        = #TEMPPICKDETAIL.rowid, 
                         @c_PICKDETAILKey = #TEMPPICKDETAIL.PICKDETAILKey, 
                         @c_ConsigneeKey  = #TEMPPICKDETAIL.ConsigneeKey,
                         @d_DeliveryDate  = #TEMPPICKDETAIL.DeliveryDate,
                         @c_sku           = SKU.SKU,      
                         @n_StdGrossWGT   = ISNULL(SKU.StdGrossWGT,0),           
                         @n_STDCube       = ISNULL(SKU.STDCube,0),      
                         @n_QtyPick       = ISNULL(#TEMPPICKDETAIL.Qty,0), 
                         @c_CartonType    = Cartonization.CartonType,
                         @n_MaxWeight     = ISNULL(Cartonization.MaxWeight,0),      
                         @n_MaxCube       = ISNULL(Cartonization.[Cube],0),          
                         @n_CaseCnt       = PACK.casecnt,
                         @n_Innerpack     = PACK.innerpack,
                         @c_uom           = #TEMPPICKDETAIL.uom
                  FROM #TEMPPICKDETAIL (NOLOCK)
                  JOIN SKU     (NOLOCK) ON ( #TEMPPICKDETAIL.Storerkey = SKU.StorerKey ) 
                                             AND ( #TEMPPICKDETAIL.Sku = SKU.Sku )
                  JOIN Storer (NOLOCK) on ( Storer.StorerKey = #TEMPPICKDETAIL.StorerKey )      
                  JOIN Cartonization (NOLOCK) on ( Cartonization.CartonizationGroup = Storer.CartonGroup )  
                                             AND ( Cartonization.CartonType = CASE #TEMPPICKDETAIL.UOM WHEN '1' THEN 'Pallet' WHEN '2' THEN 'Pallet' ELSE 'Tote' END )  
                  JOIN Pack (NOLOCK) ON ( #TEMPPICKDETAIL.Packkey = Pack.Packkey)
	               Where ISNULL(#TEMPPICKDETAIL.Qty,0) > 0      
                  AND   LEN(ISNULL(#TEMPPICKDETAIL.DropID, '')) = 0       
                  AND   SKU.StdGrossWGT <= Cartonization.MaxWeight    -- Not process for wrong setup,  cartonization weight/cube is less then SKU QTY 1     
                  AND   SKU.STDCube <=  Cartonization.[Cube]  
                  AND   (SKU.StdGrossWGT * PACK.casecnt) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.casecnt) <= Cartonization.[Cube]
                  AND   (SKU.StdGrossWGT * PACK.innerpack) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.innerpack) <= Cartonization.[Cube]
                  AND   #TEMPPICKDETAIL.Rowid > @n_rowid1
                  AND   SKU.Color = @c_Color
                  Order by #TEMPPICKDETAIL.rowid

	               IF ISNULL(RTRIM(@n_rowid1), 0) = 0 OR ISNULL(RTRIM(@c_ConsigneeKey), '') = ''
                  BEGIN
                     BREAK	
                  END			

                  SELECT @c_BreakKey = ISNULL(RTRIM(@c_ConsigneeKey), '') +'/'+ ISNULL(RTRIM(@d_DeliveryDate), '') 

                  IF @c_debug = '1'      
                  BEGIN         
                     SELECT '@c_prev_BreakKey', @c_prev_BreakKey, '@c_BreakKey', @c_BreakKey      
                  END 

                  IF @c_BreakKey <> @c_prev_BreakKey      
                  BEGIN      
                     SELECT @c_prev_breakkey = @c_breakkey      
                     Select @b_break = '1'      
                     SELECT @b_newgroup = '1'      
                  END    

                  -- break DropID      
                  IF  @b_break = '1' 
                  BEGIN 
                     IF @c_debug = '1'      
                     BEGIN        
                        SELECT '@c_CartonType', @c_CartonType       
                        SELECT '@n_MaxWeight', @n_MaxWeight, '@n_MaxCube', @n_MaxCube    
                     END      

                     SELECT @b_getdropid = '1'
                     IF @b_newgroup = '1' and @c_uom <> '1'
                     BEGIN
             	         	BEGIN TRAN               
									      INSERT INTO XDPartialPlt (DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7,
                                 									Col8, Col9, Col10, CumWeight, CumCube)
         								SELECT DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7, 
                							Col8, Col9, Col10, CumWeight, CumCube
	         							FROM #TEMPXDPARTIALPLT
                              
					  		        IF @@ERROR = 0 
    		   							BEGIN
              						WHILE @@TRANCOUNT > 0 
                								COMMIT TRAN 
                				  DELETE FROM #TEMPXDPARTIALPLT
         				    		END -- @@ERROR = 0 	
         							  ELSE
         							  BEGIN 
            						  ROLLBACK TRAN 
            						  SELECT @n_continue = 3
            						  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63353   
          							  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         								END  -- @@ERROR <> 0 
                     	
                        SELECT @n_RowId2 = a.Rowid, @c_DropID = a.DropId, @n_CumWeight = a.CumWeight, @n_CumCube = a.CumCube
                        FROM XDPartialPlt a (NOLOCK), pickdetail b (NOLOCK)
                        WHERE a.Consigneekey = @c_ConsigneeKey
                        AND CONVERT(char(8),a.DeliveryDate,1) = CONVERT(char(8),@d_DeliveryDate,1)
                        AND a.Col1 = @c_Color
                        AND a.DropId = b.DropId
                        
                        IF @@ROWCOUNT > 0
                        BEGIN
                           SELECT @b_getdropid = '0'
                          
                           BEGIN TRAN
                           DELETE FROM XDPartialPlt WHERE RowId = @n_RowId2
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63368   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END

                        SELECT @b_newgroup = '0'
                     END
                     
                     IF @b_getdropid = '1'
                     BEGIN               
                        EXECUTE nspg_GetKey      
                           'PICKToID',      
                           10,      
                           @c_DropID OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      
   
                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        SELECT @n_CumWeight = 0      
                        SELECT @n_CumCube   = 0 
                     END         
                     SELECT @n_CurQty    = 0    
                     SELECT @n_CapWeight = 0          
                     SELECT @n_CapCube   = 0  
                     SELECT @c_Remark    = ''  
                     SELECT @b_break     = '0'  
                  END

                  SELECT @n_SplitQty = 0      
                  SELECT @n_CurQty   = @n_QtyPick  

                  -- loop decs to fit in Pallet\Tote Weight\Cube      
                  WHILE @n_CurQty > 0      
                  BEGIN      
                  	
                   	 IF @c_uom = '1'  -- Full pallet
                  	 BEGIN
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100
                        SELECT @b_break = '1'
                        SELECT @c_remark = 'MAX'
                  	    BREAK
                  	 END
                  	
                     IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) <= @n_MaxWeight AND      
                        @n_CumCube   + ( @n_CurQty * @n_STDCube )     <= @n_MaxCube          
                     BEGIN      
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100
                        
                        IF @b_break = '0'
                        BEGIN
                           BEGIN TRAN
                           IF ( ( SELECT COUNT(RowId) FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID ) > 0 )
                              UPDATE #TEMPXDPARTIALPLT SET CumWeight = @n_CumWeight, CumCube = @n_CumCube
                              WHERE DropId = @c_DropID                                                      
                           ELSE                       
                              INSERT INTO #TEMPXDPARTIALPLT (DropId, Consigneekey, DeliveryDate, Col1, CumWeight, CumCube)
                                                       VALUES (@c_DropID, @c_ConsigneeKey, @d_DeliveryDate, @c_Color, @n_CumWeight, @n_CumCube)
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63369  
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert/Update #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END
                        
                        BREAK      
                     END      
                     ELSE      
                     BEGIN      
                     	  IF @c_uom = '2'   -- To ensure a case/inner pack not split to multi PID
                     	  BEGIN
                     	  	 SELECT @n_CurQty = @n_CurQty - @n_casecnt
                     		END                     		
                     	  ELSE
                     	  BEGIN
                     	  	 IF @c_uom = '3'
                        	 		SELECT @n_CurQty = @n_CurQty - @n_innerpack 
                        	 ELSE
                        	 		SELECT @n_CurQty = @n_CurQty - 1      
                        END

                        SELECT @b_break = '1'  -- cause split PickDetail and break Drop ID      
                        IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) > @n_MaxWeight
                        BEGIN
                           SELECT @n_Capacity = @n_CumWeight/@n_MaxWeight*100
                        END 

                        IF @n_CumCube   + ( @n_CurQty * @n_STDCube )     > @n_MaxCube
                        BEGIN
                           SELECT @n_Capacity = @n_CumCube/@n_MaxCube*100
                        END
                        SELECT @c_Remark = 'MAX'
                        
                        BEGIN TRAN                        
                        DELETE FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID
                        IF @@ERROR = 0 
                        BEGIN
                           WHILE @@TRANCOUNT > 0 
                              COMMIT TRAN 
                        END -- @@ERROR = 0 	
                        ELSE
                        BEGIN 
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63370   
            	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                        END  -- @@ERROR <> 0 
                     END      
                  END       
               
                  IF @c_debug = '1'      
                  BEGIN        
                     SELECT '@n_CurQty', @n_CurQty       
                     SELECT '@n_CumWeight', @n_CumWeight       
                     SELECT '@n_CumCube', @n_CumCube            
                  END   
               
                  IF @n_CurQty > 0       
                  BEGIN      
                     IF @n_CurQty <> @n_QtyPick        
                     BEGIN      
                        BEGIN TRAN  
                        SELECT @n_SplitQty = @n_QtyPick  - @n_CurQty      
                  
                        EXECUTE nspg_GetKey      
                           'PICKDETAILKEY',      
                           10,      
                           @c_New_PICKDETAILKey OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      

                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        IF @c_debug = '1'      
                        BEGIN        
                           SELECT '@c_New_PICKDETAILKey', @c_New_PICKDETAILKey      
                        END      
                   
                        -- new pick item for remaining @n_SplitQty    
                        INSERT PICKDETAIL      
                           ( PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,       
                           DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo )      
                        SELECT @c_New_PICKDETAILKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                           '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, '9', ShipFlag, @c_pickheaderkey      
                        FROM PICKDETAIL       
                        WHERE PICKDETAILKey = @c_PICKDETAILKey          
                            
                        IF @@ERROR <> 0     
                        BEGIN     
                           ROLLBACK TRAN  
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + 
                                             ': Insert Into PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END     

			               INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku, Qty, Lot, Loc, ID, Packkey, 
                                                     PickSlipNo, UOM, DropID, ConsigneeKey, C_Company, Priority, DeliveryDate, Capacity, Remark, PrintedFlag)
			               SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, PD.Lot, PD.Loc, PD.ID, PD.Packkey, 
                               PD.PickSlipNo, PD.UOM, PD.DropID, OH.CONSIGNEEKEY, OH.C_COMPANY, OH.Priority, OH.DeliveryDate, @n_Capacity, @c_Remark, @c_PrintedFlag
			                 FROM ORDERDETAIL OD (NOLOCK), PICKDETAIL PD (NOLOCK), ORDERS OH (NOLOCK) 
			                WHERE PD.ORDERKEY = OD.ORDERKEY 
				               AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER 
                           AND OH.ORDERKEY = OD.ORDERKEY
				               AND PD.PICKDETAILKey = @c_New_PICKDETAILKey   
                     
                        IF @@ERROR <> 0 
                        BEGIN
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63302   
   		                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           BREAK  
                        END  -- @@ERROR <> 0  
             
                        -- existing DROPID carton allow qty (@n_CurQty)   , remaining qty  (@n_SplitQty) next DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,      
                            UOMQTY = CASE UOM WHEN '6' THEN @n_CurQty ELSE UOMQty END ,     
                            DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey      
  
                        IF @@ERROR <> 0       
                        BEGIN  
                           ROLLBACK TRAN     
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END  

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,
                            DropID = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey  
                     END      
                     ELSE      
                     BEGIN      
                        -- Full Pickdetail item Qty for the DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey    
    
                        IF @@ERROR <> 0       
                        BEGIN      
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END   

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set DropID   = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,     
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey       
                     END  -- @n_CurQty <> @n_QtyPick          
                  END  -- @n_CurQty > 0      
                  ELSE -- @n_CurQty = 0
                    SELECT @n_rowid1 = @n_rowid1 - 1  -- Whole pickdetail line cannot fit reculculate with new pallet id

               END  -- WHILE 1=1 
               SET ROWCOUNT 0 
               -- Generate DropID if not data found 

		      END  -- WHILE 1=1 
            DROP Table #TEMPPICK6

         END  
         ----------------------------------------------------------------------------         
         /* END @c_ConfigKey = 'PID_PG6'                                           */
         ----------------------------------------------------------------------------
         ----------------------------------------------------------------------------         
         /* @c_ConfigKey = 'PID_PG7'                                               */
         ----------------------------------------------------------------------------
         IF @c_ConfigKey = 'PID_PG7' AND @c_SValue = '1'
         BEGIN

            SELECT @c_row = '0'

            CREATE TABLE #TEMPPICK7 (
	         Rowid			    int IDENTITY(1,1),
            Size            NVARCHAR(5),
            PickslipNo		 NVARCHAR(10) NULL)  

            INSERT INTO #TEMPPICK7 (Size, PickslipNo) 
            SELECT SKU.Size, MAX(PickslipNo)
            FROM #TEMPPICKDETAIL (NOLOCK)
            JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU )
            GROUP BY SKU.Size
            ORDER BY SKU.Size

            IF @c_debug = '1'      
            BEGIN      
               SELECT * FROM #TEMPPICK7 (NOLOCK)
            END

		      SELECT @n_rowid = 0 		
   	
            WHILE 1=1 
            BEGIN
			      SELECT @n_rowid = Min(rowid) 
			        FROM #TEMPPICK7 	
			       WHERE Rowid > @n_rowid

			      IF @n_rowid IS NULL OR @n_rowid = 0 BREAK				

			      Select @c_Size = Size,
                      @c_PickslipNo = PickslipNo 
			        from #TEMPPICK7 
			       Where Rowid = @n_rowid

               IF (@c_firsttime = 'N' AND ISNULL(@c_PickslipNo, '') = '') --re-allocation use the existing pickslipno
               BEGIN
                   SELECT @c_PickSlipNo = pickheaderkey, @c_pickheaderkey = pickheaderkey
                   FROM PickHeader (NOLOCK) 
                   WHERE ExternOrderKey = @c_refkey 
                   AND Zone = 'XD'
               END

               IF ISNULL(@c_PickslipNo, '') = ''
               BEGIN
			         EXECUTE nspg_GetKey 
				         'PICKSLIP',
				         8,   
				         @c_pickheaderkey     OUTPUT,
				         @b_success   	      OUTPUT,
				         @n_err       	      OUTPUT,
				         @c_errmsg    	      OUTPUT
      				
			         IF @n_err <> 0 
			         BEGIN
				         select @n_continue = 3
				         Break 
			         END
      				
			         IF @c_type = 'P' 
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END
			         ELSE
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END  -- @c_type = 'P' 
      				
			         select @c_row = Convert(char(10), convert(int, @c_row) + 1) 

                  IF @c_debug = '1'      
                  BEGIN      
                     SELECT ' @c_pickheaderkey =' + @c_pickheaderkey 
                  END

                  BEGIN TRAN 

			         INSERT INTO PICKHEADER (PickHeaderKey,    WaveKey,    ExternOrderKey, PickType, Zone, TrafficCop)
			         VALUES (@c_pickheaderkey, @c_row, @c_refkey,     '0',      'XD',  '')

                  IF @@ERROR = 0 
                  BEGIN
                     WHILE @@TRANCOUNT > 0 
                        COMMIT TRAN 
                  END 	
                  ELSE
                  BEGIN
                     ROLLBACK TRAN 
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63321   
      		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PickHeader Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                     BREAK 
                  END  -- @@ERROR = 0 

                  IF @n_continue = 1 OR @n_continue = 2  
                  BEGIN
				         BEGIN TRAN 

                     UPDATE #TEMPPICKDETAIL 
                        SET PICKSLIPNO = @c_pickheaderkey 
                        FROM  #TEMPPICKDETAIL
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU )
                                               AND SKU.Size = @c_Size      	
				         SELECT @n_err = @@ERROR
      			
                     IF @n_err = 0 
                     BEGIN
                        WHILE @@TRANCOUNT > 0 
                           COMMIT TRAN 
                     END 	
                     ELSE
                     BEGIN
                        ROLLBACK TRAN 
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63322   
         		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
					         Break
                     END  -- @n_err = 0 

                     IF @c_debug = '1'      
                     BEGIN      
                        SELECT PICKSLIPNO
                        FROM #TEMPPICKDETAIL 
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
                                               AND SKU.Size = @c_Size 
                     END

                  END  -- @n_continue = 1 OR @n_continue = 2
               END  -- ISNULL(@c_PickslipNo, '') = ''
               ELSE
                  SELECT @c_pickheaderkey = @c_PickslipNo 

               -- Generate DropID if not data found 
               SELECT @n_rowid1         = 0 
               SELECT @b_break          = '0'  
               SELECT @c_BreakKey       = ''
               SELECT @c_prev_BreakKey  = ''               
               SELECT @b_newgroup       = '0'      

               SET ROWCOUNT 1 		
               WHILE 1=1 
               BEGIN
                  SELECT @c_PICKDETAILKey = ''
                  SELECT @c_ConsigneeKey = ''
                  SELECT @d_DeliveryDate = ''  
                  SELECT @c_sku = ''  
                  SELECT @n_StdGrossWGT = ''  
                  SELECT @n_STDCube = ''  
                  SELECT @n_QtyPick = 0 
                  SELECT @c_CartonType = '' 
                  SELECT @n_MaxWeight = '' 
                  SELECT @n_MaxCube = '' 
	                SELECT @n_casecnt = 0      
                  SELECT @n_innerpack = 0               
                  SELECT @c_uom = ''

                  SELECT @n_rowid1        = #TEMPPICKDETAIL.rowid, 
                         @c_PICKDETAILKey = #TEMPPICKDETAIL.PICKDETAILKey, 
                         @c_ConsigneeKey  = #TEMPPICKDETAIL.ConsigneeKey,
                         @d_DeliveryDate  = #TEMPPICKDETAIL.DeliveryDate,
                         @c_sku           = SKU.SKU,      
                         @n_StdGrossWGT   = ISNULL(SKU.StdGrossWGT,0),           
                         @n_STDCube       = ISNULL(SKU.STDCube,0),      
                         @n_QtyPick       = ISNULL(#TEMPPICKDETAIL.Qty,0), 
                         @c_CartonType    = Cartonization.CartonType,
                         @n_MaxWeight     = ISNULL(Cartonization.MaxWeight,0),      
                         @n_MaxCube       = ISNULL(Cartonization.[Cube],0),          
                         @n_CaseCnt       = PACK.casecnt,
                         @n_Innerpack     = PACK.innerpack,
                         @c_uom           = #TEMPPICKDETAIL.uom
                  FROM #TEMPPICKDETAIL (NOLOCK)
                  JOIN SKU     (NOLOCK) ON ( #TEMPPICKDETAIL.Storerkey = SKU.StorerKey ) 
                                             AND ( #TEMPPICKDETAIL.Sku = SKU.Sku )
                  JOIN Storer (NOLOCK) on ( Storer.StorerKey = #TEMPPICKDETAIL.StorerKey )      
                  JOIN Cartonization (NOLOCK) on ( Cartonization.CartonizationGroup = Storer.CartonGroup )  
                                             AND ( Cartonization.CartonType = CASE #TEMPPICKDETAIL.UOM WHEN '1' THEN 'Pallet' WHEN '2' THEN 'Pallet' ELSE 'Tote' END )  
                  JOIN Pack (NOLOCK) ON ( #TEMPPICKDETAIL.Packkey = Pack.Packkey)
	               Where ISNULL(#TEMPPICKDETAIL.Qty,0) > 0      
                  AND   LEN(ISNULL(#TEMPPICKDETAIL.DropID, '')) = 0       
                  AND   SKU.StdGrossWGT <= Cartonization.MaxWeight    -- Not process for wrong setup,  cartonization weight/cube is less then SKU QTY 1     
                  AND   SKU.STDCube <=  Cartonization.[Cube]  
                  AND   (SKU.StdGrossWGT * PACK.casecnt) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.casecnt) <= Cartonization.[Cube]
                  AND   (SKU.StdGrossWGT * PACK.innerpack) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.innerpack) <= Cartonization.[Cube]
                  AND   #TEMPPICKDETAIL.Rowid > @n_rowid1
                  AND   SKU.Size = @c_Size 
                  Order by #TEMPPICKDETAIL.rowid

	               IF ISNULL(RTRIM(@n_rowid1), 0) = 0 OR ISNULL(RTRIM(@c_ConsigneeKey), '') = ''
                  BEGIN
                     BREAK	
                  END			

                  SELECT @c_BreakKey = ISNULL(RTRIM(@c_ConsigneeKey), '') +'/'+ ISNULL(RTRIM(@d_DeliveryDate), '') 

                  IF @c_debug = '1'      
                  BEGIN         
                     SELECT '@c_prev_BreakKey', @c_prev_BreakKey, '@c_BreakKey', @c_BreakKey      
                  END 

                  IF @c_BreakKey <> @c_prev_BreakKey      
                  BEGIN      
                     SELECT @c_prev_breakkey = @c_breakkey      
                     Select @b_break = '1'      
                     SELECT @b_newgroup = '1'      
                  END    

                  -- break DropID      
                  IF  @b_break = '1' 
                  BEGIN 
                     IF @c_debug = '1'      
                     BEGIN        
                        SELECT '@c_CartonType', @c_CartonType       
                        SELECT '@n_MaxWeight', @n_MaxWeight, '@n_MaxCube', @n_MaxCube    
                     END      
                     
                     SELECT @b_getdropid = '1'
                     IF @b_newgroup = '1' and @c_uom <> '1'
                     BEGIN
             	         	BEGIN TRAN               
									      INSERT INTO XDPartialPlt (DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7,
                                 									Col8, Col9, Col10, CumWeight, CumCube)
         								SELECT DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7, 
                							Col8, Col9, Col10, CumWeight, CumCube
	         							FROM #TEMPXDPARTIALPLT
                              
					  		        IF @@ERROR = 0 
    		   							BEGIN
              						WHILE @@TRANCOUNT > 0 
                								COMMIT TRAN 
                				  DELETE FROM #TEMPXDPARTIALPLT
         				    		END -- @@ERROR = 0 	
         							  ELSE
         							  BEGIN 
            						  ROLLBACK TRAN 
            						  SELECT @n_continue = 3
            						  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63353   
          							  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         								END  -- @@ERROR <> 0 
                     	
                        SELECT @n_RowId2 = a.Rowid, @c_DropID = a.DropId, @n_CumWeight = a.CumWeight, @n_CumCube = a.CumCube
                        FROM XDPartialPlt a (NOLOCK), pickdetail b (NOLOCK)
                        WHERE a.Consigneekey = @c_ConsigneeKey
                        AND CONVERT(char(8),a.DeliveryDate,1) = CONVERT(char(8),@d_DeliveryDate,1)
                        AND a.Col1 = @c_Size
                        AND a.DropId = b.DropId
                        
                        IF @@ROWCOUNT > 0
                        BEGIN
                           SELECT @b_getdropid = '0'
                          
                           BEGIN TRAN
                           DELETE FROM XDPartialPlt WHERE RowId = @n_RowId2
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63371   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END

                        SELECT @b_newgroup = '0'
                     END
                     
                     IF @b_getdropid = '1'
                     BEGIN               
                        EXECUTE nspg_GetKey      
                           'PICKToID',      
                           10,      
                           @c_DropID OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      
   
                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        SELECT @n_CumWeight = 0      
                        SELECT @n_CumCube   = 0          
                     END
                     SELECT @n_CurQty    = 0    
                     SELECT @n_CapWeight = 0          
                     SELECT @n_CapCube   = 0  
                     SELECT @c_Remark    = ''  
                     SELECT @b_break     = '0'  
                  END

                  SELECT @n_SplitQty = 0      
                  SELECT @n_CurQty   = @n_QtyPick  

                  -- loop decs to fit in Pallet\Tote Weight\Cube      
                  WHILE @n_CurQty > 0      
                  BEGIN      

                   	 IF @c_uom = '1'  -- Full pallet
                  	 BEGIN
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100
                        SELECT @b_break = '1'
                        SELECT @c_remark = 'MAX'
                  	    BREAK
                  	 END
                  	
                     IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) <= @n_MaxWeight AND      
                        @n_CumCube   + ( @n_CurQty * @n_STDCube )     <= @n_MaxCube          
                     BEGIN      
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100

                        IF @b_break = '0'
                        BEGIN
                           BEGIN TRAN
                           IF ( ( SELECT COUNT(RowId) FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID ) > 0 )
                              UPDATE #TEMPXDPARTIALPLT SET CumWeight = @n_CumWeight, CumCube = @n_CumCube
                              WHERE DropId = @c_DropID                                                      
                           ELSE                       
                              INSERT INTO #TEMPXDPARTIALPLT (DropId, Consigneekey, DeliveryDate, Col1, CumWeight, CumCube)
                                                       VALUES (@c_DropID, @c_ConsigneeKey, @d_DeliveryDate, @c_Size, @n_CumWeight, @n_CumCube)
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63372   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert/Update #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END
                        
                        BREAK      
                     END      
                     ELSE      
                     BEGIN      
                     	  IF @c_uom = '2'   -- To ensure a case/inner pack not split to multi PID
                     	  BEGIN
                     	  	 SELECT @n_CurQty = @n_CurQty - @n_casecnt
                     		END                     		
                     	  ELSE
                     	  BEGIN
                     	  	 IF @c_uom = '3'
                        	 		SELECT @n_CurQty = @n_CurQty - @n_innerpack 
                        	 ELSE
                        	 		SELECT @n_CurQty = @n_CurQty - 1      
                        END

                        SELECT @b_break = '1'  -- cause split PickDetail and break Drop ID      
                        IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) > @n_MaxWeight
                        BEGIN
                           SELECT @n_Capacity = @n_CumWeight/@n_MaxWeight*100
                        END 

                        IF @n_CumCube   + ( @n_CurQty * @n_STDCube )     > @n_MaxCube
                        BEGIN
                           SELECT @n_Capacity = @n_CumCube/@n_MaxCube*100
                        END
                        SELECT @c_Remark = 'MAX'
                        
                        BEGIN TRAN                        
                        DELETE FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID
                        IF @@ERROR = 0 
                        BEGIN
                           WHILE @@TRANCOUNT > 0 
                              COMMIT TRAN 
                        END -- @@ERROR = 0 	
                        ELSE
                        BEGIN 
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63373   
            	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                        END  -- @@ERROR <> 0 

                     END      
                  END       
               
                  IF @c_debug = '1'      
                  BEGIN        
                     SELECT '@n_CurQty', @n_CurQty       
                     SELECT '@n_CumWeight', @n_CumWeight       
                     SELECT '@n_CumCube', @n_CumCube            
                  END   
               
                  IF @n_CurQty > 0       
                  BEGIN      
                     IF @n_CurQty <> @n_QtyPick        
                     BEGIN      
                        BEGIN TRAN  
                        SELECT @n_SplitQty = @n_QtyPick  - @n_CurQty      
                  
                        EXECUTE nspg_GetKey      
                           'PICKDETAILKEY',      
                           10,      
                           @c_New_PICKDETAILKey OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      

                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        IF @c_debug = '1'      
                        BEGIN        
                           SELECT '@c_New_PICKDETAILKey', @c_New_PICKDETAILKey      
                        END      
                   
                        -- new pick item for remaining @n_SplitQty    
                        INSERT PICKDETAIL      
                           ( PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,       
                           DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo )      
                        SELECT @c_New_PICKDETAILKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                           '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, '9', ShipFlag, @c_pickheaderkey      
                        FROM PICKDETAIL       
                        WHERE PICKDETAILKey = @c_PICKDETAILKey          
                            
                        IF @@ERROR <> 0     
                        BEGIN     
                           ROLLBACK TRAN  
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + 
                                             ': Insert Into PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END     

			               INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku, Qty, Lot, Loc, ID, Packkey, 
                                                     PickSlipNo, UOM, DropID, ConsigneeKey, C_Company, Priority, DeliveryDate, Capacity, Remark, PrintedFlag)
			               SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, PD.Lot, PD.Loc, PD.ID, PD.Packkey, 
                               PD.PickSlipNo, PD.UOM, PD.DropID, OH.CONSIGNEEKEY, OH.C_COMPANY, OH.Priority, OH.DeliveryDate, @n_Capacity, @c_Remark, @c_PrintedFlag
			                 FROM ORDERDETAIL OD (NOLOCK), PICKDETAIL PD (NOLOCK), ORDERS OH (NOLOCK) 
			                WHERE PD.ORDERKEY = OD.ORDERKEY 
				               AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER 
                           AND OH.ORDERKEY = OD.ORDERKEY
				               AND PD.PICKDETAILKey = @c_New_PICKDETAILKey   
                     
                        IF @@ERROR <> 0 
                        BEGIN
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63302   
   		                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           BREAK  
                        END  -- @@ERROR <> 0  
             
                        -- existing DROPID carton allow qty (@n_CurQty)   , remaining qty  (@n_SplitQty) next DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,      
                            UOMQTY = CASE UOM WHEN '6' THEN @n_CurQty ELSE UOMQty END ,     
                            DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey      
  
                        IF @@ERROR <> 0       
                        BEGIN  
                           ROLLBACK TRAN     
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END  

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,
                            DropID = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey  
                     END      
                     ELSE      
                     BEGIN      
                        -- Full Pickdetail item Qty for the DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey    
    
                        IF @@ERROR <> 0       
                        BEGIN      
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END   

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set DropID   = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,     
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey       
                     END  -- @n_CurQty <> @n_QtyPick          
                  END  -- @n_CurQty > 0      
                  ELSE -- @n_CurQty = 0
                    SELECT @n_rowid1 = @n_rowid1 - 1  -- Whole pickdetail line cannot fit reculculate with new pallet id

               END  -- WHILE 1=1 
               SET ROWCOUNT 0 
               -- Generate DropID if not data found 

		      END  -- WHILE 1=1 
            DROP Table #TEMPPICK7

         END  
         ----------------------------------------------------------------------------         
         /* END @c_ConfigKey = 'PID_PG7'                                           */
         ----------------------------------------------------------------------------
         ----------------------------------------------------------------------------         
         /* @c_ConfigKey = 'PID_PG8'                                               */
         ----------------------------------------------------------------------------
         IF @c_ConfigKey = 'PID_PG8' AND @c_SValue = '1'
         BEGIN

            SELECT @c_row = '0'

            CREATE TABLE #TEMPPICK8 (
	         Rowid			    int IDENTITY(1,1),
            Measurement     NVARCHAR(5),
            PickslipNo		 NVARCHAR(10) NULL)  

            INSERT INTO #TEMPPICK8 (Measurement, PickslipNo) 
            SELECT SKU.Measurement, MAX(PickslipNo)
            FROM #TEMPPICKDETAIL (NOLOCK)
            JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
            GROUP BY SKU.Measurement
            ORDER BY SKU.Measurement 

            IF @c_debug = '1'      
            BEGIN      
               SELECT * FROM #TEMPPICK8 (NOLOCK)
            END

		      SELECT @n_rowid = 0 		
   	
            WHILE 1=1 
            BEGIN
			      SELECT @n_rowid = Min(rowid) 
			        FROM #TEMPPICK8 	
			       WHERE Rowid > @n_rowid

			      IF @n_rowid IS NULL OR @n_rowid = 0 BREAK				

			      Select @c_Measurement = Measurement,
                      @c_PickslipNo = PickslipNo                          
			        from #TEMPPICK8 
			       Where Rowid = @n_rowid

               IF (@c_firsttime = 'N' AND ISNULL(@c_PickslipNo, '') = '') --re-allocation use the existing pickslipno
               BEGIN
                   SELECT @c_PickSlipNo = pickheaderkey, @c_pickheaderkey = pickheaderkey
                   FROM PickHeader (NOLOCK) 
                   WHERE ExternOrderKey = @c_refkey 
                   AND Zone = 'XD'
               END

               IF ISNULL(@c_PickslipNo, '') = ''
               BEGIN
			         EXECUTE nspg_GetKey 
				         'PICKSLIP',
				         8,   
				         @c_pickheaderkey     OUTPUT,
				         @b_success   	      OUTPUT,
				         @n_err       	      OUTPUT,
				         @c_errmsg    	      OUTPUT
      				
			         IF @n_err <> 0 
			         BEGIN
				         select @n_continue = 3
				         Break 
			         END
      				
			         IF @c_type = 'P' 
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END
			         ELSE
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END  -- @c_type = 'P' 
      				
			         select @c_row = Convert(char(10), convert(int, @c_row) + 1) 

                  IF @c_debug = '1'      
                  BEGIN      
                     SELECT ' @c_pickheaderkey =' + @c_pickheaderkey 
                  END

                  BEGIN TRAN 

			         INSERT INTO PICKHEADER (PickHeaderKey,    WaveKey,    ExternOrderKey, PickType, Zone, TrafficCop)
			         VALUES (@c_pickheaderkey, @c_row, @c_refkey,     '0',      'XD',  '')

                  IF @@ERROR = 0 
                  BEGIN
                     WHILE @@TRANCOUNT > 0 
                        COMMIT TRAN 
                  END 	
                  ELSE
                  BEGIN
                     ROLLBACK TRAN 
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63323   
      		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PickHeader Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                     BREAK 
                  END  -- @@ERROR = 0 

                  IF @n_continue = 1 OR @n_continue = 2  
                  BEGIN
				         BEGIN TRAN 

                     UPDATE #TEMPPICKDETAIL 
                        SET PICKSLIPNO = @c_pickheaderkey 
                        FROM  #TEMPPICKDETAIL
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
                                               AND SKU.Measurement = @c_Measurement          	
				         SELECT @n_err = @@ERROR
      			
                     IF @n_err = 0 
                     BEGIN
                        WHILE @@TRANCOUNT > 0 
                           COMMIT TRAN 
                     END 	
                     ELSE
                     BEGIN
                        ROLLBACK TRAN 
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63324   
         		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
					         Break
                     END  -- @n_err = 0 

                     IF @c_debug = '1'      
                     BEGIN      
                        SELECT PICKSLIPNO
                        FROM #TEMPPICKDETAIL 
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
                                               AND SKU.Measurement = @c_Measurement 
                     END

                  END  -- @n_continue = 1 OR @n_continue = 2
               END  -- ISNULL(@c_PickslipNo, '') = ''
               ELSE
                  SELECT @c_pickheaderkey = @c_PickslipNo 

               -- Generate DropID if not data found 
               SELECT @n_rowid1         = 0 
               SELECT @b_break          = '0'  
               SELECT @c_BreakKey       = ''
               SELECT @c_prev_BreakKey  = ''               
               SELECT @b_newgroup       = '0'      

               SET ROWCOUNT 1 		
               WHILE 1=1 
               BEGIN
                  SELECT @c_PICKDETAILKey = ''
                  SELECT @c_ConsigneeKey = ''
                  SELECT @d_DeliveryDate = ''  
                  SELECT @c_sku = ''  
                  SELECT @n_StdGrossWGT = ''  
                  SELECT @n_STDCube = ''  
                  SELECT @n_QtyPick = 0 
                  SELECT @c_CartonType = '' 
                  SELECT @n_MaxWeight = '' 
                  SELECT @n_MaxCube = '' 
	                SELECT @n_casecnt = 0      
                  SELECT @n_innerpack = 0               
                  SELECT @c_uom = ''

                  SELECT @n_rowid1        = #TEMPPICKDETAIL.rowid, 
                         @c_PICKDETAILKey = #TEMPPICKDETAIL.PICKDETAILKey, 
                         @c_ConsigneeKey  = #TEMPPICKDETAIL.ConsigneeKey,
                         @d_DeliveryDate  = #TEMPPICKDETAIL.DeliveryDate,
                         @c_sku           = SKU.SKU,      
                         @n_StdGrossWGT   = ISNULL(SKU.StdGrossWGT,0),           
                         @n_STDCube       = ISNULL(SKU.STDCube,0),      
                         @n_QtyPick       = ISNULL(#TEMPPICKDETAIL.Qty,0), 
                         @c_CartonType    = Cartonization.CartonType,
                         @n_MaxWeight     = ISNULL(Cartonization.MaxWeight,0),      
                         @n_MaxCube       = ISNULL(Cartonization.[Cube],0),          
                         @n_CaseCnt       = PACK.casecnt,
                         @n_Innerpack     = PACK.innerpack,
                         @c_uom           = #TEMPPICKDETAIL.uom
                  FROM #TEMPPICKDETAIL (NOLOCK)
                  JOIN SKU     (NOLOCK) ON ( #TEMPPICKDETAIL.Storerkey = SKU.StorerKey ) 
                                             AND ( #TEMPPICKDETAIL.Sku = SKU.Sku )
                  JOIN Storer (NOLOCK) on ( Storer.StorerKey = #TEMPPICKDETAIL.StorerKey )      
                  JOIN Cartonization (NOLOCK) on ( Cartonization.CartonizationGroup = Storer.CartonGroup )  
                                             AND ( Cartonization.CartonType = CASE #TEMPPICKDETAIL.UOM WHEN '1' THEN 'Pallet' WHEN '2' THEN 'Pallet' ELSE 'Tote' END )  
                  JOIN Pack (NOLOCK) ON ( #TEMPPICKDETAIL.Packkey = Pack.Packkey)
	               Where ISNULL(#TEMPPICKDETAIL.Qty,0) > 0      
                  AND   LEN(ISNULL(#TEMPPICKDETAIL.DropID, '')) = 0       
                  AND   SKU.StdGrossWGT <= Cartonization.MaxWeight    -- Not process for wrong setup,  cartonization weight/cube is less then SKU QTY 1     
                  AND   SKU.STDCube <=  Cartonization.[Cube]  
                  AND   (SKU.StdGrossWGT * PACK.casecnt) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.casecnt) <= Cartonization.[Cube]
                  AND   (SKU.StdGrossWGT * PACK.innerpack) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.innerpack) <= Cartonization.[Cube]
                  AND   #TEMPPICKDETAIL.Rowid > @n_rowid1
                  AND   SKU.Measurement = @c_Measurement
                  Order by #TEMPPICKDETAIL.rowid

	               IF ISNULL(RTRIM(@n_rowid1), 0) = 0 OR ISNULL(RTRIM(@c_ConsigneeKey), '') = ''
                  BEGIN
                     BREAK	
                  END			

                  SELECT @c_BreakKey = ISNULL(RTRIM(@c_ConsigneeKey), '') +'/'+ ISNULL(RTRIM(@d_DeliveryDate), '') 

                  IF @c_debug = '1'      
                  BEGIN         
                     SELECT '@c_prev_BreakKey', @c_prev_BreakKey, '@c_BreakKey', @c_BreakKey      
                  END 

                  IF @c_BreakKey <> @c_prev_BreakKey      
                  BEGIN      
                     SELECT @c_prev_breakkey = @c_breakkey      
                     Select @b_break = '1'      
                     SELECT @b_newgroup = '1'      
                  END    

                  -- break DropID      
                  IF  @b_break = '1' 
                  BEGIN 
                     IF @c_debug = '1'      
                     BEGIN        
                        SELECT '@c_CartonType', @c_CartonType       
                        SELECT '@n_MaxWeight', @n_MaxWeight, '@n_MaxCube', @n_MaxCube    
                     END     
                      
                     SELECT @b_getdropid = '1'
                     IF @b_newgroup = '1' and @c_uom <> '1'
                     BEGIN
             	         	BEGIN TRAN               
									      INSERT INTO XDPartialPlt (DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7,
                                 									Col8, Col9, Col10, CumWeight, CumCube)
         								SELECT DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7, 
                							Col8, Col9, Col10, CumWeight, CumCube
	         							FROM #TEMPXDPARTIALPLT
                              
					  		        IF @@ERROR = 0 
    		   							BEGIN
              						WHILE @@TRANCOUNT > 0 
                								COMMIT TRAN 
                				  DELETE FROM #TEMPXDPARTIALPLT
         				    		END -- @@ERROR = 0 	
         							  ELSE
         							  BEGIN 
            						  ROLLBACK TRAN 
            						  SELECT @n_continue = 3
            						  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63353   
          							  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         								END  -- @@ERROR <> 0 
                     	
                        SELECT @n_RowId2 = a.Rowid, @c_DropID = a.DropId, @n_CumWeight = a.CumWeight, @n_CumCube = a.CumCube
                        FROM XDPartialPlt a (NOLOCK), pickdetail b (NOLOCK)
                        WHERE a.Consigneekey = @c_ConsigneeKey
                        AND CONVERT(char(8),a.DeliveryDate,1) = CONVERT(char(8),@d_DeliveryDate,1)
                        AND a.Col1 = @c_Measurement 
                        AND a.DropId = b.DropId
                        
                        IF @@ROWCOUNT > 0
                        BEGIN
                           SELECT @b_getdropid = '0'
                          
                           BEGIN TRAN
                           DELETE FROM XDPartialPlt WHERE RowId = @n_RowId2
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63377   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END

                        SELECT @b_newgroup = '0'
                     END
                     
                     IF @b_getdropid = '1'
                     BEGIN               
                        EXECUTE nspg_GetKey      
                           'PICKToID',      
                           10,      
                           @c_DropID OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      
   
                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        SELECT @n_CumWeight = 0      
                        SELECT @n_CumCube   = 0 
                     END         
                     SELECT @n_CurQty    = 0    
                     SELECT @n_CapWeight = 0          
                     SELECT @n_CapCube   = 0  
                     SELECT @c_Remark    = ''  
                     SELECT @b_break     = '0'  
                  END

                  SELECT @n_SplitQty = 0      
                  SELECT @n_CurQty   = @n_QtyPick  

                  -- loop decs to fit in Pallet\Tote Weight\Cube      
                  WHILE @n_CurQty > 0      
                  BEGIN      

                   	 IF @c_uom = '1'  -- Full pallet
                  	 BEGIN
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100
                        SELECT @b_break = '1'
                        SELECT @c_remark = 'MAX'
                  	    BREAK
                  	 END
                  	
                     IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) <= @n_MaxWeight AND      
                        @n_CumCube   + ( @n_CurQty * @n_STDCube )     <= @n_MaxCube          
                     BEGIN      
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100
                        
                        IF @b_break = '0'
                        BEGIN
                           BEGIN TRAN
                           IF ( ( SELECT COUNT(RowId) FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID ) > 0 )
                              UPDATE #TEMPXDPARTIALPLT SET CumWeight = @n_CumWeight, CumCube = @n_CumCube
                              WHERE DropId = @c_DropID                                                      
                           ELSE                       
                              INSERT INTO #TEMPXDPARTIALPLT (DropId, Consigneekey, DeliveryDate, Col1, CumWeight, CumCube)
                                                       VALUES (@c_DropID, @c_ConsigneeKey, @d_DeliveryDate, @c_Measurement, @n_CumWeight, @n_CumCube)
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63378  
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert/Update #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END
                        
                        BREAK      
                     END      
                     ELSE      
                     BEGIN      
                     	  IF @c_uom = '2'   -- To ensure a case/inner pack not split to multi PID
                     	  BEGIN
                     	  	 SELECT @n_CurQty = @n_CurQty - @n_casecnt
                     		END                     		
                     	  ELSE
                     	  BEGIN
                     	  	 IF @c_uom = '3'
                        	 		SELECT @n_CurQty = @n_CurQty - @n_innerpack 
                        	 ELSE
                        	 		SELECT @n_CurQty = @n_CurQty - 1      
                        END

                        SELECT @b_break = '1'  -- cause split PickDetail and break Drop ID      
                        IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) > @n_MaxWeight
                        BEGIN
                           SELECT @n_Capacity = @n_CumWeight/@n_MaxWeight*100
                        END 

                        IF @n_CumCube   + ( @n_CurQty * @n_STDCube )     > @n_MaxCube
                        BEGIN
                           SELECT @n_Capacity = @n_CumCube/@n_MaxCube*100
                        END
                        SELECT @c_Remark = 'MAX'
                        
                        BEGIN TRAN                        
                        DELETE FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID
                        IF @@ERROR = 0 
                        BEGIN
                           WHILE @@TRANCOUNT > 0 
                              COMMIT TRAN 
                        END -- @@ERROR = 0 	
                        ELSE
                        BEGIN 
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63379   
            	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                        END  -- @@ERROR <> 0 

                     END      
                  END       
               
                  IF @c_debug = '1'      
                  BEGIN        
                     SELECT '@n_CurQty', @n_CurQty       
                     SELECT '@n_CumWeight', @n_CumWeight       
                     SELECT '@n_CumCube', @n_CumCube            
                  END   
               
                  IF @n_CurQty > 0       
                  BEGIN      
                     IF @n_CurQty <> @n_QtyPick        
                     BEGIN      
                        BEGIN TRAN  
                        SELECT @n_SplitQty = @n_QtyPick  - @n_CurQty      
                  
                        EXECUTE nspg_GetKey      
                           'PICKDETAILKEY',      
                           10,      
                           @c_New_PICKDETAILKey OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      

                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        IF @c_debug = '1'      
                        BEGIN        
                           SELECT '@c_New_PICKDETAILKey', @c_New_PICKDETAILKey      
                        END      
                   
                        -- new pick item for remaining @n_SplitQty    
                        INSERT PICKDETAIL      
                           ( PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,       
                           DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo )      
                        SELECT @c_New_PICKDETAILKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                           '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, '9', ShipFlag, @c_pickheaderkey      
                        FROM PICKDETAIL       
                        WHERE PICKDETAILKey = @c_PICKDETAILKey          
                            
                        IF @@ERROR <> 0     
                        BEGIN     
                           ROLLBACK TRAN  
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + 
                                             ': Insert Into PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END     

			               INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku, Qty, Lot, Loc, ID, Packkey, 
                                                     PickSlipNo, UOM, DropID, ConsigneeKey, C_Company, Priority, DeliveryDate, Capacity, Remark, PrintedFlag)
			               SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, PD.Lot, PD.Loc, PD.ID, PD.Packkey, 
                               PD.PickSlipNo, PD.UOM, PD.DropID, OH.CONSIGNEEKEY, OH.C_COMPANY, OH.Priority, OH.DeliveryDate, @n_Capacity, @c_Remark, @c_PrintedFlag
			                 FROM ORDERDETAIL OD (NOLOCK), PICKDETAIL PD (NOLOCK), ORDERS OH (NOLOCK) 
			                WHERE PD.ORDERKEY = OD.ORDERKEY 
				               AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER 
                           AND OH.ORDERKEY = OD.ORDERKEY
				               AND PD.PICKDETAILKey = @c_New_PICKDETAILKey   
                     
                        IF @@ERROR <> 0 
                        BEGIN
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63302   
   		                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           BREAK  
                        END  -- @@ERROR <> 0  
             
                        -- existing DROPID carton allow qty (@n_CurQty)   , remaining qty  (@n_SplitQty) next DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,      
                            UOMQTY = CASE UOM WHEN '6' THEN @n_CurQty ELSE UOMQty END ,     
                            DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey      
  
                        IF @@ERROR <> 0       
                        BEGIN  
                           ROLLBACK TRAN     
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END  

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,
                            DropID = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey  
                     END      
                     ELSE      
                     BEGIN      
                        -- Full Pickdetail item Qty for the DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey    
    
                        IF @@ERROR <> 0       
                        BEGIN      
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END   

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set DropID   = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,     
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey       
                     END  -- @n_CurQty <> @n_QtyPick          
                  END  -- @n_CurQty > 0      
                  ELSE -- @n_CurQty = 0
                    SELECT @n_rowid1 = @n_rowid1 - 1  -- Whole pickdetail line cannot fit reculculate with new pallet id

               END  -- WHILE 1=1 
               SET ROWCOUNT 0 
               -- Generate DropID if not data found 

		      END  -- WHILE 1=1 
            DROP Table #TEMPPICK8

         END  
         ----------------------------------------------------------------------------         
         /* END @c_ConfigKey = 'PID_PG8'                                           */
         ----------------------------------------------------------------------------
         ----------------------------------------------------------------------------         
         /* @c_ConfigKey = 'PID_PG12'                                              */
         ----------------------------------------------------------------------------
         IF @c_ConfigKey = 'PID_PG12' AND @c_SValue = '1'
         BEGIN

            SELECT @c_row = '0'

            CREATE TABLE #TEMPPICK12 (
	         Rowid			    int IDENTITY(1,1),
	         BUSR5           NVARCHAR(30),
            CLASS           NVARCHAR(10),
            PickslipNo		 NVARCHAR(10) NULL)  

            INSERT INTO #TEMPPICK12 (BUSR5, CLASS, PickslipNo) 
            SELECT SKU.BUSR5, SKU.CLASS, MAX(PickslipNo)
            FROM #TEMPPICKDETAIL (NOLOCK)
            JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
            GROUP BY SKU.BUSR5, SKU.CLASS
            ORDER BY SKU.BUSR5, SKU.CLASS

            IF @c_debug = '1'      
            BEGIN      
               SELECT * FROM #TEMPPICK12 (NOLOCK)
            END

		      SELECT @n_rowid = 0 		
   	
            WHILE 1=1 
            BEGIN
			      SELECT @n_rowid = Min(rowid) 
			        FROM #TEMPPICK12 	
			       WHERE Rowid > @n_rowid

			      IF @n_rowid IS NULL OR @n_rowid = 0 BREAK				

			      Select @c_BUSR5 = BUSR5, 
                      @c_CLASS = CLASS,
                      @c_PickslipNo = PickslipNo                         
			        from #TEMPPICK12 
			       Where Rowid = @n_rowid

               IF (@c_firsttime = 'N' AND ISNULL(@c_PickslipNo, '') = '') --re-allocation use the existing pickslipno
               BEGIN
                   SELECT @c_PickSlipNo = pickheaderkey, @c_pickheaderkey = pickheaderkey
                   FROM PickHeader (NOLOCK) 
                   WHERE ExternOrderKey = @c_refkey 
                   AND Zone = 'XD'
               END

               IF ISNULL(@c_PickslipNo, '') = ''
               BEGIN
			         EXECUTE nspg_GetKey 
				         'PICKSLIP',
				         8,   
				         @c_pickheaderkey     OUTPUT,
				         @b_success   	      OUTPUT,
				         @n_err       	      OUTPUT,
				         @c_errmsg    	      OUTPUT
      				
			         IF @n_err <> 0 
			         BEGIN
				         select @n_continue = 3
				         Break 
			         END
      				
			         IF @c_type = 'P' 
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END
			         ELSE
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END  -- @c_type = 'P' 
      				
			         select @c_row = Convert(char(10), convert(int, @c_row) + 1) 

                  IF @c_debug = '1'      
                  BEGIN      
                     SELECT ' @c_pickheaderkey =' + @c_pickheaderkey 
                  END

                  BEGIN TRAN 

			         INSERT INTO PICKHEADER (PickHeaderKey,    WaveKey,    ExternOrderKey, PickType, Zone, TrafficCop)
			         VALUES (@c_pickheaderkey, @c_row, @c_refkey,     '0',      'XD',  '')

                  IF @@ERROR = 0 
                  BEGIN
                     WHILE @@TRANCOUNT > 0 
                        COMMIT TRAN 
                  END 	
                  ELSE
                  BEGIN
                     ROLLBACK TRAN 
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63325   
      		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PickHeader Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                     BREAK 
                  END  -- @@ERROR = 0 

                  IF @n_continue = 1 OR @n_continue = 2  
                  BEGIN
				         BEGIN TRAN 

                     UPDATE #TEMPPICKDETAIL 
                        SET PICKSLIPNO = @c_pickheaderkey 
                        FROM  #TEMPPICKDETAIL
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
                                               AND SKU.BUSR5 = @c_BUSR5
                                               AND SKU.CLASS = @c_CLASS        	
				         SELECT @n_err = @@ERROR
      			
                     IF @n_err = 0 
                     BEGIN
                        WHILE @@TRANCOUNT > 0 
                           COMMIT TRAN 
                     END 	
                     ELSE
                     BEGIN
                        ROLLBACK TRAN 
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63326   
         		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
					         Break
                     END  -- @n_err = 0 

                     IF @c_debug = '1'      
                     BEGIN      
                        SELECT PICKSLIPNO
                        FROM #TEMPPICKDETAIL 
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
                                               AND SKU.BUSR5 = @c_BUSR5
                                               AND SKU.CLASS = @c_CLASS 
                     END

                  END  -- @n_continue = 1 OR @n_continue = 2
               END -- ISNULL(@c_PickslipNo, '') = ''
               ELSE
                  SELECT @c_pickheaderkey = @c_PickslipNo 

               -- Generate DropID if not data found 
               SELECT @n_rowid1         = 0 
               SELECT @b_break          = '0'  
               SELECT @c_BreakKey       = ''
               SELECT @c_prev_BreakKey  = ''               
               SELECT @b_newgroup       = '0'      

               SET ROWCOUNT 1 		
               WHILE 1=1 
               BEGIN
                  SELECT @c_PICKDETAILKey = ''
                  SELECT @c_ConsigneeKey = ''
                  SELECT @d_DeliveryDate = ''  
                  SELECT @c_sku = ''  
                  SELECT @n_StdGrossWGT = ''  
                  SELECT @n_STDCube = ''  
                  SELECT @n_QtyPick = 0 
                  SELECT @c_CartonType = '' 
                  SELECT @n_MaxWeight = '' 
                  SELECT @n_MaxCube = '' 
	                SELECT @n_casecnt = 0      
                  SELECT @n_innerpack = 0               
                  SELECT @c_uom = ''

                  SELECT @n_rowid1        = #TEMPPICKDETAIL.rowid, 
                         @c_PICKDETAILKey = #TEMPPICKDETAIL.PICKDETAILKey, 
                         @c_ConsigneeKey  = #TEMPPICKDETAIL.ConsigneeKey,
                         @d_DeliveryDate  = #TEMPPICKDETAIL.DeliveryDate,
                         @c_sku           = SKU.SKU,      
                         @n_StdGrossWGT   = ISNULL(SKU.StdGrossWGT,0),           
                         @n_STDCube       = ISNULL(SKU.STDCube,0),      
                         @n_QtyPick       = ISNULL(#TEMPPICKDETAIL.Qty,0), 
                         @c_CartonType    = Cartonization.CartonType,
                         @n_MaxWeight     = ISNULL(Cartonization.MaxWeight,0),      
                         @n_MaxCube       = ISNULL(Cartonization.[Cube],0),          
                         @n_CaseCnt       = PACK.casecnt,
                         @n_Innerpack     = PACK.innerpack,
                         @c_uom           = #TEMPPICKDETAIL.uom
                  FROM #TEMPPICKDETAIL (NOLOCK)
                  JOIN SKU     (NOLOCK) ON ( #TEMPPICKDETAIL.Storerkey = SKU.StorerKey ) 
                                             AND ( #TEMPPICKDETAIL.Sku = SKU.Sku )
                  JOIN Storer (NOLOCK) on ( Storer.StorerKey = #TEMPPICKDETAIL.StorerKey )      
                  JOIN Cartonization (NOLOCK) on ( Cartonization.CartonizationGroup = Storer.CartonGroup )  
                                             AND ( Cartonization.CartonType = CASE #TEMPPICKDETAIL.UOM WHEN '1' THEN 'Pallet' WHEN '2' THEN 'Pallet' ELSE 'Tote' END )  
                  JOIN Pack (NOLOCK) ON ( #TEMPPICKDETAIL.Packkey = Pack.Packkey)
	               Where ISNULL(#TEMPPICKDETAIL.Qty,0) > 0      
                  AND   LEN(ISNULL(#TEMPPICKDETAIL.DropID, '')) = 0       
                  AND   SKU.StdGrossWGT <= Cartonization.MaxWeight    -- Not process for wrong setup,  cartonization weight/cube is less then SKU QTY 1     
                  AND   SKU.STDCube <=  Cartonization.[Cube]  
                  AND   (SKU.StdGrossWGT * PACK.casecnt) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.casecnt) <= Cartonization.[Cube]
                  AND   (SKU.StdGrossWGT * PACK.innerpack) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.innerpack) <= Cartonization.[Cube]
                  AND   #TEMPPICKDETAIL.Rowid > @n_rowid1
                  AND   SKU.BUSR5 = @c_BUSR5
                  AND   SKU.CLASS = @c_CLASS 
                  Order by #TEMPPICKDETAIL.rowid

	               IF ISNULL(RTRIM(@n_rowid1), 0) = 0 OR ISNULL(RTRIM(@c_ConsigneeKey), '') = ''
                  BEGIN
                     BREAK	
                  END			

                  SELECT @c_BreakKey = ISNULL(RTRIM(@c_ConsigneeKey), '') +'/'+ ISNULL(RTRIM(@d_DeliveryDate), '') 

                  IF @c_debug = '1'      
                  BEGIN         
                     SELECT '@c_prev_BreakKey', @c_prev_BreakKey, '@c_BreakKey', @c_BreakKey      
                  END 

                  IF @c_BreakKey <> @c_prev_BreakKey      
                  BEGIN      
                     SELECT @c_prev_breakkey = @c_breakkey      
                     Select @b_break = '1'      
                     SELECT @b_newgroup = '1'      
                  END    

                  -- break DropID      
                  IF  @b_break = '1' 
                  BEGIN 
                     IF @c_debug = '1'      
                     BEGIN        
                        SELECT '@c_CartonType', @c_CartonType       
                        SELECT '@n_MaxWeight', @n_MaxWeight, '@n_MaxCube', @n_MaxCube    
                     END      
                     
                     SELECT @b_getdropid = '1'
                     IF @b_newgroup = '1' and @c_uom <> '1'
                     BEGIN
             	         	BEGIN TRAN               
									      INSERT INTO XDPartialPlt (DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7,
                                 									Col8, Col9, Col10, CumWeight, CumCube)
         								SELECT DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7, 
                							Col8, Col9, Col10, CumWeight, CumCube
	         							FROM #TEMPXDPARTIALPLT
                              
					  		        IF @@ERROR = 0 
    		   							BEGIN
              						WHILE @@TRANCOUNT > 0 
                								COMMIT TRAN 
                				  DELETE FROM #TEMPXDPARTIALPLT
         				    		END -- @@ERROR = 0 	
         							  ELSE
         							  BEGIN 
            						  ROLLBACK TRAN 
            						  SELECT @n_continue = 3
            						  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63353   
          							  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         								END  -- @@ERROR <> 0 
                     	
                        SELECT @n_RowId2 = a.Rowid, @c_DropID = a.DropId, @n_CumWeight = a.CumWeight, @n_CumCube = a.CumCube
                        FROM XDPartialPlt a (NOLOCK), pickdetail b (NOLOCK)
                        WHERE a.Consigneekey = @c_ConsigneeKey
                        AND CONVERT(char(8),a.DeliveryDate,1) = CONVERT(char(8),@d_DeliveryDate,1)
                        AND a.Col1 = @c_BUSR5
                        AND a.Col2 = @c_CLASS 
                        AND a.DropId = b.DropId
                        
                        IF @@ROWCOUNT > 0
                        BEGIN
                           SELECT @b_getdropid = '0'
                          
                           BEGIN TRAN
                           DELETE FROM XDPartialPlt WHERE RowId = @n_RowId2
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63380   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END

                        SELECT @b_newgroup = '0'
                     END
                     
                     IF @b_getdropid = '1'
                     BEGIN               
                        EXECUTE nspg_GetKey      
                           'PICKToID',      
                           10,      
                           @c_DropID OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      
   
                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        SELECT @n_CumWeight = 0      
                        SELECT @n_CumCube   = 0 
                     END         
                     SELECT @n_CurQty    = 0    
                     SELECT @n_CapWeight = 0          
                     SELECT @n_CapCube   = 0  
                     SELECT @c_Remark    = ''  
                     SELECT @b_break     = '0'  
                  END

                  SELECT @n_SplitQty = 0      
                  SELECT @n_CurQty   = @n_QtyPick  

                  -- loop decs to fit in Pallet\Tote Weight\Cube      
                  WHILE @n_CurQty > 0      
                  BEGIN      

                   	 IF @c_uom = '1'  -- Full pallet
                  	 BEGIN
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100
                        SELECT @b_break = '1'
                        SELECT @c_remark = 'MAX'
                  	    BREAK
                  	 END
                  	
                     IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) <= @n_MaxWeight AND      
                        @n_CumCube   + ( @n_CurQty * @n_STDCube )     <= @n_MaxCube          
                     BEGIN      
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100

                        IF @b_break = '0'
                        BEGIN
                           BEGIN TRAN
                           IF ( ( SELECT COUNT(RowId) FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID ) > 0 )
                              UPDATE #TEMPXDPARTIALPLT SET CumWeight = @n_CumWeight, CumCube = @n_CumCube
                              WHERE DropId = @c_DropID                                                      
                           ELSE                       
                              INSERT INTO #TEMPXDPARTIALPLT (DropId, Consigneekey, DeliveryDate, Col1, Col2, CumWeight, CumCube)
                                                       VALUES (@c_DropID, @c_ConsigneeKey, @d_DeliveryDate, @c_BUSR5, @c_CLASS,
                                                               @n_CumWeight, @n_CumCube)
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63381   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert/Update #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END
                        
                        BREAK      
                     END      
                     ELSE      
                     BEGIN      
                     	  IF @c_uom = '2'   -- To ensure a case/inner pack not split to multi PID
                     	  BEGIN
                     	  	 SELECT @n_CurQty = @n_CurQty - @n_casecnt
                     		END                     		
                     	  ELSE
                     	  BEGIN
                     	  	 IF @c_uom = '3'
                        	 		SELECT @n_CurQty = @n_CurQty - @n_innerpack 
                        	 ELSE
                        	 		SELECT @n_CurQty = @n_CurQty - 1      
                        END

                        SELECT @b_break = '1'  -- cause split PickDetail and break Drop ID      
                        IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) > @n_MaxWeight
                        BEGIN
                           SELECT @n_Capacity = @n_CumWeight/@n_MaxWeight*100
                        END 

                        IF @n_CumCube   + ( @n_CurQty * @n_STDCube )     > @n_MaxCube
                        BEGIN
                           SELECT @n_Capacity = @n_CumCube/@n_MaxCube*100
                        END
                        SELECT @c_Remark = 'MAX'

                        BEGIN TRAN                        
                        DELETE FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID
                        IF @@ERROR = 0 
                        BEGIN
                           WHILE @@TRANCOUNT > 0 
                              COMMIT TRAN 
                        END -- @@ERROR = 0 	
                        ELSE
                        BEGIN 
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63382   
            	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                        END  -- @@ERROR <> 0                                                
                     END      
                  END       
               
                  IF @c_debug = '1'      
                  BEGIN        
                     SELECT '@n_CurQty', @n_CurQty       
                     SELECT '@n_CumWeight', @n_CumWeight       
                     SELECT '@n_CumCube', @n_CumCube            
                  END   
               
                  IF @n_CurQty > 0       
                  BEGIN      
                     IF @n_CurQty <> @n_QtyPick        
                     BEGIN      
                        BEGIN TRAN  
                        SELECT @n_SplitQty = @n_QtyPick  - @n_CurQty      
                  
                        EXECUTE nspg_GetKey      
                           'PICKDETAILKEY',      
                           10,      
                           @c_New_PICKDETAILKey OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      

                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        IF @c_debug = '1'      
                        BEGIN        
                           SELECT '@c_New_PICKDETAILKey', @c_New_PICKDETAILKey      
                        END      
                   
                        -- new pick item for remaining @n_SplitQty    
                        INSERT PICKDETAIL      
                           ( PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,       
                           DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo )      
                        SELECT @c_New_PICKDETAILKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                           '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, '9', ShipFlag, @c_pickheaderkey      
                        FROM PICKDETAIL       
                        WHERE PICKDETAILKey = @c_PICKDETAILKey          
                            
                        IF @@ERROR <> 0     
                        BEGIN     
                           ROLLBACK TRAN  
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + 
                                             ': Insert Into PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END     

			               INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku, Qty, Lot, Loc, ID, Packkey, 
                                                     PickSlipNo, UOM, DropID, ConsigneeKey, C_Company, Priority, DeliveryDate, Capacity, Remark, PrintedFlag)
			               SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, PD.Lot, PD.Loc, PD.ID, PD.Packkey, 
                               PD.PickSlipNo, PD.UOM, PD.DropID, OH.CONSIGNEEKEY, OH.C_COMPANY, OH.Priority, OH.DeliveryDate, @n_Capacity, @c_Remark, @c_PrintedFlag
			                 FROM ORDERDETAIL OD (NOLOCK), PICKDETAIL PD (NOLOCK), ORDERS OH (NOLOCK) 
			                WHERE PD.ORDERKEY = OD.ORDERKEY 
				               AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER 
                           AND OH.ORDERKEY = OD.ORDERKEY
				               AND PD.PICKDETAILKey = @c_New_PICKDETAILKey   
                     
                        IF @@ERROR <> 0 
                        BEGIN
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63302   
   		                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           BREAK  
                        END  -- @@ERROR <> 0  
             
                        -- existing DROPID carton allow qty (@n_CurQty)   , remaining qty  (@n_SplitQty) next DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,      
                            UOMQTY = CASE UOM WHEN '6' THEN @n_CurQty ELSE UOMQty END ,     
                            DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey      
  
                        IF @@ERROR <> 0       
                        BEGIN  
                           ROLLBACK TRAN     
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END  

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,
                            DropID = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey  
                     END      
                     ELSE      
                     BEGIN      
                        -- Full Pickdetail item Qty for the DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey    
    
                        IF @@ERROR <> 0       
                        BEGIN      
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END   

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set DropID   = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,     
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey       
                     END  -- @n_CurQty <> @n_QtyPick          
                  END  -- @n_CurQty > 0      
                  ELSE -- @n_CurQty = 0
                    SELECT @n_rowid1 = @n_rowid1 - 1  -- Whole pickdetail line cannot fit reculculate with new pallet id

               END  -- WHILE 1=1 
               SET ROWCOUNT 0 
               -- Generate DropID if not data found

		      END  -- WHILE 1=1 
            DROP Table #TEMPPICK12

         END  
         ----------------------------------------------------------------------------         
         /* END @c_ConfigKey = 'PID_PG12'                                          */
         ----------------------------------------------------------------------------
         ----------------------------------------------------------------------------         
         /* @c_ConfigKey = 'PID_PG123'                                             */
         ----------------------------------------------------------------------------
         IF @c_ConfigKey = 'PID_PG123' AND @c_SValue = '1'
         BEGIN

            SELECT @c_row = '0'

            CREATE TABLE #TEMPPICK123 (
	         Rowid			    int IDENTITY(1,1),
	         BUSR5           NVARCHAR(30),
            CLASS           NVARCHAR(10),
            itemclass       NVARCHAR(10),
            PickslipNo		 NVARCHAR(10) NULL)  

            INSERT INTO #TEMPPICK123 (BUSR5, CLASS, itemclass, PickslipNo) 
            SELECT SKU.BUSR5, SKU.CLASS, SKU.itemclass, MAX(PickslipNo)
            FROM #TEMPPICKDETAIL (NOLOCK)
            JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU )
            GROUP BY SKU.BUSR5, SKU.CLASS, SKU.itemclass
            ORDER BY SKU.BUSR5, SKU.CLASS, SKU.itemclass

            IF @c_debug = '1'      
            BEGIN      
               SELECT * FROM #TEMPPICK123 (NOLOCK)
            END

		      SELECT @n_rowid = 0 		
   	
            WHILE 1=1 
            BEGIN
			      SELECT @n_rowid = Min(rowid) 
			        FROM #TEMPPICK123 	
			       WHERE Rowid > @n_rowid

			      IF @n_rowid IS NULL OR @n_rowid = 0 BREAK				

			      Select @c_BUSR5 = BUSR5, 
                      @c_CLASS = CLASS, 
                      @c_itemclass = itemclass,
                      @c_PickslipNo = PickslipNo
			        from #TEMPPICK123 
			       Where Rowid = @n_rowid

               IF (@c_firsttime = 'N' AND ISNULL(@c_PickslipNo, '') = '') --re-allocation use the existing pickslipno
               BEGIN
                   SELECT @c_PickSlipNo = pickheaderkey, @c_pickheaderkey = pickheaderkey
                   FROM PickHeader (NOLOCK) 
                   WHERE ExternOrderKey = @c_refkey 
                   AND Zone = 'XD'
               END

               IF ISNULL(@c_PickslipNo, '') = ''
               BEGIN
			         EXECUTE nspg_GetKey 
				         'PICKSLIP',
				         8,   
				         @c_pickheaderkey     OUTPUT,
				         @b_success   	      OUTPUT,
				         @n_err       	      OUTPUT,
				         @c_errmsg    	      OUTPUT
      				
			         IF @n_err <> 0 
			         BEGIN
				         select @n_continue = 3
				         Break 
			         END
      				
			         IF @c_type = 'P' 
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END
			         ELSE
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END  -- @c_type = 'P' 
      				
			         select @c_row = Convert(char(10), convert(int, @c_row) + 1) 

                  IF @c_debug = '1'      
                  BEGIN      
                     SELECT ' @c_pickheaderkey =' + @c_pickheaderkey 
                  END

                  BEGIN TRAN 

			         INSERT INTO PICKHEADER (PickHeaderKey,    WaveKey,    ExternOrderKey, PickType, Zone, TrafficCop)
			         VALUES (@c_pickheaderkey, @c_row, @c_refkey,     '0',      'XD',  '')

                  IF @@ERROR = 0 
                  BEGIN
                     WHILE @@TRANCOUNT > 0 
                        COMMIT TRAN 
                  END 	
                  ELSE
                  BEGIN
                     ROLLBACK TRAN 
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63327   
      		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PickHeader Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                     BREAK 
                  END  -- @@ERROR = 0 

                  IF @n_continue = 1 OR @n_continue = 2  
                  BEGIN
				         BEGIN TRAN 

                     UPDATE #TEMPPICKDETAIL 
                        SET PICKSLIPNO = @c_pickheaderkey 
                        FROM  #TEMPPICKDETAIL
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
                                               AND SKU.BUSR5 = @c_BUSR5
                                               AND SKU.CLASS = @c_CLASS 
                                               AND SKU.itemclass = @c_itemclass      	
				         SELECT @n_err = @@ERROR
      			
                     IF @n_err = 0 
                     BEGIN
                        WHILE @@TRANCOUNT > 0 
                           COMMIT TRAN 
                     END 	
                     ELSE
                     BEGIN
                        ROLLBACK TRAN 
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63328   
         		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
					         Break
                     END  -- @n_err = 0 

                     IF @c_debug = '1'      
                     BEGIN      
                        SELECT PICKSLIPNO
                        FROM #TEMPPICKDETAIL 
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
                                               AND SKU.BUSR5 = @c_BUSR5
                                               AND SKU.CLASS = @c_CLASS 
                                               AND SKU.itemclass = @c_itemclass 
                     END

                  END  -- @n_continue = 1 OR @n_continue = 2
               END  -- ISNULL(@c_PickslipNo, '') = ''
               ELSE
                  SELECT @c_pickheaderkey = @c_PickslipNo 

               -- Generate DropID if not data found 
               SELECT @n_rowid1         = 0 
               SELECT @b_break          = '0'  
               SELECT @c_BreakKey       = ''
               SELECT @c_prev_BreakKey  = ''               
               SELECT @b_newgroup       = '0'      

               SET ROWCOUNT 1 		
               WHILE 1=1 
               BEGIN
                  SELECT @c_PICKDETAILKey = ''
                  SELECT @c_ConsigneeKey = ''
                  SELECT @d_DeliveryDate = ''  
                  SELECT @c_sku = ''  
                  SELECT @n_StdGrossWGT = ''  
                  SELECT @n_STDCube = ''  
                  SELECT @n_QtyPick = 0 
                  SELECT @c_CartonType = '' 
                  SELECT @n_MaxWeight = '' 
                  SELECT @n_MaxCube = '' 
	                SELECT @n_casecnt = 0      
                  SELECT @n_innerpack = 0               
                  SELECT @c_uom = ''

                  SELECT @n_rowid1        = #TEMPPICKDETAIL.rowid, 
                         @c_PICKDETAILKey = #TEMPPICKDETAIL.PICKDETAILKey, 
                         @c_ConsigneeKey  = #TEMPPICKDETAIL.ConsigneeKey,
                         @d_DeliveryDate  = #TEMPPICKDETAIL.DeliveryDate,
                         @c_sku           = SKU.SKU,      
                         @n_StdGrossWGT   = ISNULL(SKU.StdGrossWGT,0),           
                         @n_STDCube       = ISNULL(SKU.STDCube,0),      
                         @n_QtyPick       = ISNULL(#TEMPPICKDETAIL.Qty,0), 
                         @c_CartonType    = Cartonization.CartonType,
                         @n_MaxWeight     = ISNULL(Cartonization.MaxWeight,0),      
                         @n_MaxCube       = ISNULL(Cartonization.[Cube],0),          
                         @n_CaseCnt       = PACK.casecnt,
                         @n_Innerpack     = PACK.innerpack,
                         @c_uom           = #TEMPPICKDETAIL.uom
                  FROM #TEMPPICKDETAIL (NOLOCK)
                  JOIN SKU     (NOLOCK) ON ( #TEMPPICKDETAIL.Storerkey = SKU.StorerKey ) 
                                             AND ( #TEMPPICKDETAIL.Sku = SKU.Sku )
                  JOIN Storer (NOLOCK) on ( Storer.StorerKey = #TEMPPICKDETAIL.StorerKey )      
                  JOIN Cartonization (NOLOCK) on ( Cartonization.CartonizationGroup = Storer.CartonGroup )  
                                             AND ( Cartonization.CartonType = CASE #TEMPPICKDETAIL.UOM WHEN '1' THEN 'Pallet' WHEN '2' THEN 'Pallet' ELSE 'Tote' END )  
                  JOIN Pack (NOLOCK) ON ( #TEMPPICKDETAIL.Packkey = Pack.Packkey)
	               Where ISNULL(#TEMPPICKDETAIL.Qty,0) > 0      
                  AND   LEN(ISNULL(#TEMPPICKDETAIL.DropID, '')) = 0       
                  AND   SKU.StdGrossWGT <= Cartonization.MaxWeight    -- Not process for wrong setup,  cartonization weight/cube is less then SKU QTY 1     
                  AND   SKU.STDCube <=  Cartonization.[Cube]  
                  AND   (SKU.StdGrossWGT * PACK.casecnt) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.casecnt) <= Cartonization.[Cube]
                  AND   (SKU.StdGrossWGT * PACK.innerpack) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.innerpack) <= Cartonization.[Cube]
                  AND   #TEMPPICKDETAIL.Rowid > @n_rowid1
                  AND   SKU.BUSR5 = @c_BUSR5
                  AND   SKU.CLASS = @c_CLASS 
                  AND   SKU.itemclass = @c_itemclass
                  Order by #TEMPPICKDETAIL.rowid

	               IF ISNULL(RTRIM(@n_rowid1), 0) = 0 OR ISNULL(RTRIM(@c_ConsigneeKey), '') = ''
                  BEGIN
                     BREAK	
                  END			

                  SELECT @c_BreakKey = ISNULL(RTRIM(@c_ConsigneeKey), '') +'/'+ ISNULL(RTRIM(@d_DeliveryDate), '') 

                  IF @c_debug = '1'      
                  BEGIN         
                     SELECT '@c_prev_BreakKey', @c_prev_BreakKey, '@c_BreakKey', @c_BreakKey      
                  END 

                  IF @c_BreakKey <> @c_prev_BreakKey      
                  BEGIN      
                     SELECT @c_prev_breakkey = @c_breakkey      
                     Select @b_break = '1'      
                     SELECT @b_newgroup = '1'      
                  END    

                  -- break DropID      
                  IF  @b_break = '1' 
                  BEGIN 
                     IF @c_debug = '1'      
                     BEGIN        
                        SELECT '@c_CartonType', @c_CartonType       
                        SELECT '@n_MaxWeight', @n_MaxWeight, '@n_MaxCube', @n_MaxCube    
                     END     
                      
                     SELECT @b_getdropid = '1'
                     IF @b_newgroup = '1' and @c_uom <> '1'
                     BEGIN
             	         	BEGIN TRAN               
									      INSERT INTO XDPartialPlt (DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7,
                                 									Col8, Col9, Col10, CumWeight, CumCube)
         								SELECT DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7, 
                							Col8, Col9, Col10, CumWeight, CumCube
	         							FROM #TEMPXDPARTIALPLT
                              
					  		        IF @@ERROR = 0 
    		   							BEGIN
              						WHILE @@TRANCOUNT > 0 
                								COMMIT TRAN 
                				  DELETE FROM #TEMPXDPARTIALPLT
         				    		END -- @@ERROR = 0 	
         							  ELSE
         							  BEGIN 
            						  ROLLBACK TRAN 
            						  SELECT @n_continue = 3
            						  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63353   
          							  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         								END  -- @@ERROR <> 0 
                     	
                        SELECT @n_RowId2 = a.Rowid, @c_DropID = a.DropId, @n_CumWeight = a.CumWeight, @n_CumCube = a.CumCube
                        FROM XDPartialPlt a (NOLOCK), pickdetail b (NOLOCK)
                        WHERE a.Consigneekey = @c_ConsigneeKey
                        AND CONVERT(char(8),a.DeliveryDate,1) = CONVERT(char(8),@d_DeliveryDate,1)
                        AND a.Col1 = @c_BUSR5
                        AND a.Col2 = @c_CLASS 
                        AND a.Col3 = @c_itemclass 
                        AND a.DropId = b.DropId
                        
                        IF @@ROWCOUNT > 0
                        BEGIN
                           SELECT @b_getdropid = '0'
                          
                           BEGIN TRAN
                           DELETE FROM XDPartialPlt WHERE RowId = @n_RowId2
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63382   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END

                        SELECT @b_newgroup = '0'
                     END
                     
                     IF @b_getdropid = '1'
                     BEGIN               
                        EXECUTE nspg_GetKey      
                           'PICKToID',      
                           10,      
                           @c_DropID OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      
   
                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        SELECT @n_CumWeight = 0      
                        SELECT @n_CumCube   = 0 
                     END         
                     SELECT @n_CurQty    = 0    
                     SELECT @n_CapWeight = 0          
                     SELECT @n_CapCube   = 0  
                     SELECT @c_Remark    = ''  
                     SELECT @b_break     = '0'  
                  END

                  SELECT @n_SplitQty = 0      
                  SELECT @n_CurQty   = @n_QtyPick  

                  -- loop decs to fit in Pallet\Tote Weight\Cube      
                  WHILE @n_CurQty > 0                        
                  BEGIN      
                  	
                   	 IF @c_uom = '1'  -- Full pallet
                  	 BEGIN
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100
                        SELECT @b_break = '1'
                        SELECT @c_remark = 'MAX'
                  	    BREAK
                  	 END
                  	
                     IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) <= @n_MaxWeight AND      
                        @n_CumCube   + ( @n_CurQty * @n_STDCube )     <= @n_MaxCube          
                     BEGIN      
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100

                        IF @b_break = '0'
                        BEGIN
                           BEGIN TRAN
                           IF ( ( SELECT COUNT(RowId) FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID ) > 0 )
                              UPDATE #TEMPXDPARTIALPLT SET CumWeight = @n_CumWeight, CumCube = @n_CumCube
                              WHERE DropId = @c_DropID                                                      
                           ELSE                       
                              INSERT INTO #TEMPXDPARTIALPLT (DropId, Consigneekey, DeliveryDate, Col1, Col2, Col3, CumWeight, CumCube)
                                                       VALUES (@c_DropID, @c_ConsigneeKey, @d_DeliveryDate, @c_BUSR5, @c_CLASS,
                                                               @c_itemclass, @n_CumWeight, @n_CumCube)
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63382   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert/Update #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END
                        
                        BREAK      
                     END      
                     ELSE      
                     BEGIN      
                     	  IF @c_uom = '2'   -- To ensure a case/inner pack not split to multi PID
                     	  BEGIN
                     	  	 SELECT @n_CurQty = @n_CurQty - @n_casecnt
                     		END                     		
                     	  ELSE
                     	  BEGIN
                     	  	 IF @c_uom = '3'
                        	 		SELECT @n_CurQty = @n_CurQty - @n_innerpack 
                        	 ELSE
                        	 		SELECT @n_CurQty = @n_CurQty - 1      
                        END

                        SELECT @b_break = '1'  -- cause split PickDetail and break Drop ID      
                        IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) > @n_MaxWeight
                        BEGIN
                           SELECT @n_Capacity = @n_CumWeight/@n_MaxWeight*100
                        END 

                        IF @n_CumCube   + ( @n_CurQty * @n_STDCube )     > @n_MaxCube
                        BEGIN
                           SELECT @n_Capacity = @n_CumCube/@n_MaxCube*100
                        END
                        SELECT @c_Remark = 'MAX'
                        
                        BEGIN TRAN                        
                        DELETE FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID
                        IF @@ERROR = 0 
                        BEGIN
                           WHILE @@TRANCOUNT > 0 
                              COMMIT TRAN 
                        END -- @@ERROR = 0 	
                        ELSE
                        BEGIN 
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63384   
            	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                        END  -- @@ERROR <> 0 

                     END      
                  END       
               
                  IF @c_debug = '1'      
                  BEGIN        
                     SELECT '@n_CurQty', @n_CurQty       
                     SELECT '@n_CumWeight', @n_CumWeight       
                     SELECT '@n_CumCube', @n_CumCube            
                  END   
               
                  IF @n_CurQty > 0       
                  BEGIN      
                     IF @n_CurQty <> @n_QtyPick        
                     BEGIN      
                        BEGIN TRAN  
                        SELECT @n_SplitQty = @n_QtyPick  - @n_CurQty      
                  
                        EXECUTE nspg_GetKey      
                           'PICKDETAILKEY',      
                           10,      
                           @c_New_PICKDETAILKey OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      

                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        IF @c_debug = '1'      
                        BEGIN        
                           SELECT '@c_New_PICKDETAILKey', @c_New_PICKDETAILKey      
                        END      
                   
                        -- new pick item for remaining @n_SplitQty    
                        INSERT PICKDETAIL      
                           ( PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,       
                           DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo )      
                        SELECT @c_New_PICKDETAILKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                           '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, '9', ShipFlag, @c_pickheaderkey      
                        FROM PICKDETAIL       
                        WHERE PICKDETAILKey = @c_PICKDETAILKey          
                            
                        IF @@ERROR <> 0     
                        BEGIN     
                           ROLLBACK TRAN  
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + 
                                             ': Insert Into PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END     

			               INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku, Qty, Lot, Loc, ID, Packkey, 
                                                     PickSlipNo, UOM, DropID, ConsigneeKey, C_Company, Priority, DeliveryDate, Capacity, Remark, PrintedFlag)
			               SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, PD.Lot, PD.Loc, PD.ID, PD.Packkey, 
                               PD.PickSlipNo, PD.UOM, PD.DropID, OH.CONSIGNEEKEY, OH.C_COMPANY, OH.Priority, OH.DeliveryDate, @n_Capacity, @c_Remark, @c_PrintedFlag
			                 FROM ORDERDETAIL OD (NOLOCK), PICKDETAIL PD (NOLOCK), ORDERS OH (NOLOCK) 
			                WHERE PD.ORDERKEY = OD.ORDERKEY 
				               AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER 
                           AND OH.ORDERKEY = OD.ORDERKEY
				               AND PD.PICKDETAILKey = @c_New_PICKDETAILKey   
                     
                        IF @@ERROR <> 0 
                        BEGIN
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63302   
   		                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           BREAK  
                        END  -- @@ERROR <> 0  
             
                        -- existing DROPID carton allow qty (@n_CurQty)   , remaining qty  (@n_SplitQty) next DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,      
                            UOMQTY = CASE UOM WHEN '6' THEN @n_CurQty ELSE UOMQty END ,     
                            DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey      
  
                        IF @@ERROR <> 0       
                        BEGIN  
                           ROLLBACK TRAN     
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END  

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,
                            DropID = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey  
                     END      
                     ELSE      
                     BEGIN      
                        -- Full Pickdetail item Qty for the DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey    
    
                        IF @@ERROR <> 0       
                        BEGIN      
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END   

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set DropID   = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,     
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey       
                     END  -- @n_CurQty <> @n_QtyPick          
                  END  -- @n_CurQty > 0      
                  ELSE -- @n_CurQty = 0
                    SELECT @n_rowid1 = @n_rowid1 - 1  -- Whole pickdetail line cannot fit reculculate with new pallet id

               END  -- WHILE 1=1 
               SET ROWCOUNT 0 
               -- Generate DropID if not data found

		      END  -- WHILE 1=1 
            DROP Table #TEMPPICK123

         END  
         ----------------------------------------------------------------------------         
         /* END @c_ConfigKey = 'PID_PG123'                                         */
         ----------------------------------------------------------------------------
         ----------------------------------------------------------------------------         
         /* @c_ConfigKey = 'PID_PG1234'                                             */
         ----------------------------------------------------------------------------
         IF @c_ConfigKey = 'PID_PG1234' AND @c_SValue = '1'
         BEGIN

            SELECT @c_row = '0'

            CREATE TABLE #TEMPPICK1234 (
	         Rowid			    int IDENTITY(1,1),
	         BUSR5           NVARCHAR(30),
            CLASS           NVARCHAR(10),
            itemclass       NVARCHAR(10),
            SKUGROUP        NVARCHAR(10),
            PickslipNo		 NVARCHAR(10) NULL)  

            INSERT INTO #TEMPPICK1234 (BUSR5, CLASS, itemclass, SKUGROUP, PickslipNo) 
            SELECT SKU.BUSR5, SKU.CLASS, SKU.itemclass, SKU.SKUGROUP, MAX(PickslipNo)
            FROM #TEMPPICKDETAIL (NOLOCK)
            JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
            GROUP BY SKU.BUSR5, SKU.CLASS, SKU.itemclass, SKU.SKUGROUP
            ORDER BY SKU.BUSR5, SKU.CLASS, SKU.itemclass, SKU.SKUGROUP

            IF @c_debug = '1'      
            BEGIN      
               SELECT * FROM #TEMPPICK1234 (NOLOCK)
            END

		      SELECT @n_rowid = 0 		
   	
            WHILE 1=1 
            BEGIN
			      SELECT @n_rowid = Min(rowid) 
			        FROM #TEMPPICK1234 	
			       WHERE Rowid > @n_rowid

			      IF @n_rowid IS NULL OR @n_rowid = 0 BREAK				

			      Select @c_BUSR5 = BUSR5, 
                      @c_CLASS = CLASS, 
                      @c_itemclass = itemclass, 
                      @c_SKUGROUP = SKUGROUP, 
                      @c_PickslipNo = PickslipNo
			        from #TEMPPICK1234 
			       Where Rowid = @n_rowid

               IF (@c_firsttime = 'N' AND ISNULL(@c_PickslipNo, '') = '') --re-allocation use the existing pickslipno
               BEGIN
                   SELECT @c_PickSlipNo = pickheaderkey, @c_pickheaderkey = pickheaderkey
                   FROM PickHeader (NOLOCK) 
                   WHERE ExternOrderKey = @c_refkey 
                   AND Zone = 'XD'
               END

               IF ISNULL(@c_PickslipNo, '') = ''
               BEGIN
			         EXECUTE nspg_GetKey 
				         'PICKSLIP',
				         8,   
				         @c_pickheaderkey     OUTPUT,
				         @b_success   	      OUTPUT,
				         @n_err       	      OUTPUT,
				         @c_errmsg    	      OUTPUT
      				
			         IF @n_err <> 0 
			         BEGIN
				         select @n_continue = 3
				         Break 
			         END
      				
			         IF @c_type = 'P' 
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END
			         ELSE
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END  -- @c_type = 'P' 
      				
			         select @c_row = Convert(char(10), convert(int, @c_row) + 1) 

                  IF @c_debug = '1'      
                  BEGIN      
                     SELECT ' @c_pickheaderkey =' + @c_pickheaderkey 
                  END

                  BEGIN TRAN 

			         INSERT INTO PICKHEADER (PickHeaderKey,    WaveKey,    ExternOrderKey, PickType, Zone, TrafficCop)
			         VALUES (@c_pickheaderkey, @c_row, @c_refkey,     '0',      'XD',  '')

                  IF @@ERROR = 0 
                  BEGIN
                     WHILE @@TRANCOUNT > 0 
                        COMMIT TRAN 
                  END 	
                  ELSE
                  BEGIN
                     ROLLBACK TRAN 
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63329   
      		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PickHeader Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                     BREAK 
                  END  -- @@ERROR = 0 

                  IF @n_continue = 1 OR @n_continue = 2  
                  BEGIN
				         BEGIN TRAN 

                     UPDATE #TEMPPICKDETAIL 
                        SET PICKSLIPNO = @c_pickheaderkey 
                        FROM  #TEMPPICKDETAIL
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
                                               AND SKU.BUSR5 = @c_BUSR5
                                               AND SKU.CLASS = @c_CLASS 
                                               AND SKU.itemclass = @c_itemclass 
                                               AND SKU.SKUGROUP = @c_SKUGROUP       	
				         SELECT @n_err = @@ERROR
      			
                     IF @n_err = 0 
                     BEGIN
                        WHILE @@TRANCOUNT > 0 
                           COMMIT TRAN 
                     END 	
                     ELSE
                     BEGIN
                        ROLLBACK TRAN 
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63330   
         		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
					         Break
                     END  -- @n_err = 0 

                     IF @c_debug = '1'      
                     BEGIN      
                        SELECT PICKSLIPNO
                        FROM #TEMPPICKDETAIL 
		                  JOIN SKU (NOLOCK) on ( SKU.SKU = #TEMPPICKDETAIL.SKU ) 
                                               AND SKU.BUSR5 = @c_BUSR5
                                               AND SKU.CLASS = @c_CLASS 
                                               AND SKU.itemclass = @c_itemclass 
                                               AND SKU.SKUGROUP = @c_SKUGROUP
                     END

                  END  -- @n_continue = 1 OR @n_continue = 2
               END  -- ISNULL(@c_PickslipNo, '') = ''
               ELSE
                  SELECT @c_pickheaderkey = @c_PickslipNo 

               -- Generate DropID if not data found 
               SELECT @n_rowid1         = 0 
               SELECT @b_break          = '0'  
               SELECT @c_BreakKey       = ''
               SELECT @c_prev_BreakKey  = ''   
               SELECT @b_newgroup       = '0'      
                           
               SET ROWCOUNT 1 		
               WHILE 1=1 
               BEGIN
                  SELECT @c_PICKDETAILKey = ''
                  SELECT @c_ConsigneeKey = ''
                  SELECT @d_DeliveryDate = ''  
                  SELECT @c_sku = ''  
                  SELECT @n_StdGrossWGT = ''  
                  SELECT @n_STDCube = ''  
                  SELECT @n_QtyPick = 0 
                  SELECT @c_CartonType = '' 
                  SELECT @n_MaxWeight = '' 
                  SELECT @n_MaxCube = '' 
	                SELECT @n_casecnt = 0      
                  SELECT @n_innerpack = 0               
                  SELECT @c_uom = ''

                  SELECT @n_rowid1        = #TEMPPICKDETAIL.rowid, 
                         @c_PICKDETAILKey = #TEMPPICKDETAIL.PICKDETAILKey, 
                         @c_ConsigneeKey  = #TEMPPICKDETAIL.ConsigneeKey,
                         @d_DeliveryDate  = #TEMPPICKDETAIL.DeliveryDate,
                         @c_sku           = SKU.SKU,      
                         @n_StdGrossWGT   = ISNULL(SKU.StdGrossWGT,0),           
                         @n_STDCube       = ISNULL(SKU.STDCube,0),      
                         @n_QtyPick       = ISNULL(#TEMPPICKDETAIL.Qty,0), 
                         @c_CartonType    = Cartonization.CartonType,
                         @n_MaxWeight     = ISNULL(Cartonization.MaxWeight,0),      
                         @n_MaxCube       = ISNULL(Cartonization.[Cube],0),          
                         @n_CaseCnt       = PACK.casecnt,
                         @n_Innerpack     = PACK.innerpack,
                         @c_uom           = #TEMPPICKDETAIL.uom
                  FROM #TEMPPICKDETAIL (NOLOCK)
                  JOIN SKU     (NOLOCK) ON ( #TEMPPICKDETAIL.Storerkey = SKU.StorerKey ) 
                                             AND ( #TEMPPICKDETAIL.Sku = SKU.Sku )
                  JOIN Storer (NOLOCK) on ( Storer.StorerKey = #TEMPPICKDETAIL.StorerKey )      
                  JOIN Cartonization (NOLOCK) on ( Cartonization.CartonizationGroup = Storer.CartonGroup )  
                                             AND ( Cartonization.CartonType = CASE #TEMPPICKDETAIL.UOM WHEN '1' THEN 'Pallet' WHEN '2' THEN 'Pallet' ELSE 'Tote' END )  
                  JOIN Pack (NOLOCK) ON ( #TEMPPICKDETAIL.Packkey = Pack.Packkey)
	               Where ISNULL(#TEMPPICKDETAIL.Qty,0) > 0      
                  AND   LEN(ISNULL(#TEMPPICKDETAIL.DropID, '')) = 0       
                  AND   SKU.StdGrossWGT <= Cartonization.MaxWeight    -- Not process for wrong setup,  cartonization weight/cube is less then SKU QTY 1     
                  AND   SKU.STDCube <=  Cartonization.[Cube]  
                  AND   (SKU.StdGrossWGT * PACK.casecnt) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.casecnt) <= Cartonization.[Cube]
                  AND   (SKU.StdGrossWGT * PACK.innerpack) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.innerpack) <= Cartonization.[Cube]
                  AND   #TEMPPICKDETAIL.Rowid > @n_rowid1
                  AND   SKU.BUSR5 = @c_BUSR5
                  AND   SKU.CLASS = @c_CLASS 
                  AND   SKU.itemclass = @c_itemclass
                  AND   SKU.SKUGROUP = @c_SKUGROUP
                  Order by #TEMPPICKDETAIL.rowid

	               IF ISNULL(RTRIM(@n_rowid1), 0) = 0 OR ISNULL(RTRIM(@c_ConsigneeKey), '') = ''
                  BEGIN
                     BREAK	
                  END			

                  SELECT @c_BreakKey = ISNULL(RTRIM(@c_ConsigneeKey), '') +'/'+ ISNULL(RTRIM(@d_DeliveryDate), '') 

                  IF @c_debug = '1'      
                  BEGIN         
                     SELECT '@c_prev_BreakKey', @c_prev_BreakKey, '@c_BreakKey', @c_BreakKey      
                  END 

                  IF @c_BreakKey <> @c_prev_BreakKey      
                  BEGIN      
                     SELECT @c_prev_breakkey = @c_breakkey      
                     Select @b_break = '1'      
                     SELECT @b_newgroup = '1'      
                  END    

                  -- break DropID      
                  IF  @b_break = '1' 
                  BEGIN 
                     IF @c_debug = '1'      
                     BEGIN        
                        SELECT '@c_CartonType', @c_CartonType       
                        SELECT '@n_MaxWeight', @n_MaxWeight, '@n_MaxCube', @n_MaxCube    
                     END      
                     
                     SELECT @b_getdropid = '1'
                     IF @b_newgroup = '1' and @c_uom <> '1'
                     BEGIN
             	         	BEGIN TRAN               
									      INSERT INTO XDPartialPlt (DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7,
                                 									Col8, Col9, Col10, CumWeight, CumCube)
         								SELECT DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7, 
                							Col8, Col9, Col10, CumWeight, CumCube
	         							FROM #TEMPXDPARTIALPLT
                              
					  		        IF @@ERROR = 0 
    		   							BEGIN
              						WHILE @@TRANCOUNT > 0 
                								COMMIT TRAN 
                				  DELETE FROM #TEMPXDPARTIALPLT
         				    		END -- @@ERROR = 0 	
         							  ELSE
         							  BEGIN 
            						  ROLLBACK TRAN 
            						  SELECT @n_continue = 3
            						  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63353   
          							  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         								END  -- @@ERROR <> 0 
                     	
                        SELECT @n_RowId2 = a.Rowid, @c_DropID = a.DropId, @n_CumWeight = a.CumWeight, @n_CumCube = a.CumCube
                        FROM XDPartialPlt a (NOLOCK), pickdetail b (NOLOCK)
                        WHERE a.Consigneekey = @c_ConsigneeKey
                        AND CONVERT(char(8),a.DeliveryDate,1) = CONVERT(char(8),@d_DeliveryDate,1)
                        AND a.Col1 = @c_BUSR5
                        AND a.Col2 = @c_CLASS 
                        AND a.Col3 = @c_itemclass 
                        AND a.Col4 = @c_SKUGROUP  
                        AND a.DropId = b.DropId
                        
                        IF @@ROWCOUNT > 0
                        BEGIN
                           SELECT @b_getdropid = '0'
                          
                           BEGIN TRAN
                           DELETE FROM XDPartialPlt WHERE RowId = @n_RowId2
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63385   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END

                        SELECT @b_newgroup = '0'
                     END
                     
                     IF @b_getdropid = '1'
                     BEGIN               
                        EXECUTE nspg_GetKey      
                           'PICKToID',      
                           10,      
                           @c_DropID OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      
   
                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        SELECT @n_CumWeight = 0      
                        SELECT @n_CumCube   = 0          
                     END
                     SELECT @n_CurQty    = 0    
                     SELECT @n_CapWeight = 0          
                     SELECT @n_CapCube   = 0  
                     SELECT @c_Remark    = ''  
                     SELECT @b_break     = '0'  
                  END

                  SELECT @n_SplitQty = 0      
                  SELECT @n_CurQty   = @n_QtyPick  

                  -- loop decs to fit in Pallet\Tote Weight\Cube      
                  WHILE @n_CurQty > 0      
                  BEGIN      
                  	
                   	 IF @c_uom = '1'  -- Full pallet
                  	 BEGIN
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100
                        SELECT @b_break = '1'
                        SELECT @c_remark = 'MAX'
                  	    BREAK
                  	 END
                  	
                     IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) <= @n_MaxWeight AND      
                        @n_CumCube   + ( @n_CurQty * @n_STDCube )     <= @n_MaxCube          
                     BEGIN      
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100

                        IF @b_break = '0'
                        BEGIN
                           BEGIN TRAN
                           IF ( ( SELECT COUNT(RowId) FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID ) > 0 )
                              UPDATE #TEMPXDPARTIALPLT SET CumWeight = @n_CumWeight, CumCube = @n_CumCube
                              WHERE DropId = @c_DropID                                                      
                           ELSE                       
                              INSERT INTO #TEMPXDPARTIALPLT (DropId, Consigneekey, DeliveryDate, Col1, Col2, Col3, Col4,
                                                               CumWeight, CumCube)
                                                       VALUES (@c_DropID, @c_ConsigneeKey, @d_DeliveryDate, @c_BUSR5, @c_CLASS,
                                                               @c_itemclass, @c_SKUGROUP, @n_CumWeight, @n_CumCube)
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63386   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert/Update #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END

                        BREAK      
                     END      
                     ELSE      
                     BEGIN      
                     	  IF @c_uom = '2'   -- To ensure a case/inner pack not split to multi PID
                     	  BEGIN
                     	  	 SELECT @n_CurQty = @n_CurQty - @n_casecnt
                     		END                     		
                     	  ELSE
                     	  BEGIN
                     	  	 IF @c_uom = '3'
                        	 		SELECT @n_CurQty = @n_CurQty - @n_innerpack 
                        	 ELSE
                        	 		SELECT @n_CurQty = @n_CurQty - 1      
                        END

                        SELECT @b_break = '1'  -- cause split PickDetail and break Drop ID      
                        IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) > @n_MaxWeight
                        BEGIN
                           SELECT @n_Capacity = @n_CumWeight/@n_MaxWeight*100
                        END 

                        IF @n_CumCube   + ( @n_CurQty * @n_STDCube )     > @n_MaxCube
                        BEGIN
                           SELECT @n_Capacity = @n_CumCube/@n_MaxCube*100
                        END
                        SELECT @c_Remark = 'MAX'
                        
                        BEGIN TRAN                        
                        DELETE FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID
                        IF @@ERROR = 0 
                        BEGIN
                           WHILE @@TRANCOUNT > 0 
                              COMMIT TRAN 
                        END -- @@ERROR = 0 	
                        ELSE
                        BEGIN 
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63387   
            	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                        END  -- @@ERROR <> 0 

                     END      
                  END       
               
                  IF @c_debug = '1'      
                  BEGIN        
                     SELECT '@n_CurQty', @n_CurQty       
                     SELECT '@n_CumWeight', @n_CumWeight       
                     SELECT '@n_CumCube', @n_CumCube            
                  END   
               
                  IF @n_CurQty > 0       
                  BEGIN      
                     IF @n_CurQty <> @n_QtyPick        
                     BEGIN      
                        BEGIN TRAN  
                        SELECT @n_SplitQty = @n_QtyPick  - @n_CurQty      
                  
                        EXECUTE nspg_GetKey      
                           'PICKDETAILKEY',      
                           10,      
                           @c_New_PICKDETAILKey OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      

                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        IF @c_debug = '1'      
                        BEGIN        
                           SELECT '@c_New_PICKDETAILKey', @c_New_PICKDETAILKey      
                        END      
                   
                        -- new pick item for remaining @n_SplitQty    
                        INSERT PICKDETAIL      
                           ( PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,       
                           DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo )      
                        SELECT @c_New_PICKDETAILKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                           '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, '9', ShipFlag, @c_pickheaderkey      
                        FROM PICKDETAIL       
                        WHERE PICKDETAILKey = @c_PICKDETAILKey          
                            
                        IF @@ERROR <> 0     
                        BEGIN     
                           ROLLBACK TRAN  
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + 
                                             ': Insert Into PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END     

			               INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku, Qty, Lot, Loc, ID, Packkey, 
                                                     PickSlipNo, UOM, DropID, ConsigneeKey, C_Company, Priority, DeliveryDate, Capacity, Remark, PrintedFlag)
			               SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, PD.Lot, PD.Loc, PD.ID, PD.Packkey, 
                               PD.PickSlipNo, PD.UOM, PD.DropID, OH.CONSIGNEEKEY, OH.C_COMPANY, OH.Priority, OH.DeliveryDate, @n_Capacity, @c_Remark, @c_PrintedFlag
			                 FROM ORDERDETAIL OD (NOLOCK), PICKDETAIL PD (NOLOCK), ORDERS OH (NOLOCK) 
			                WHERE PD.ORDERKEY = OD.ORDERKEY 
				               AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER 
                           AND OH.ORDERKEY = OD.ORDERKEY
				               AND PD.PICKDETAILKey = @c_New_PICKDETAILKey   
                     
                        IF @@ERROR <> 0 
                        BEGIN
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63302   
   		                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           BREAK  
                        END  -- @@ERROR <> 0  
             
                        -- existing DROPID carton allow qty (@n_CurQty)   , remaining qty  (@n_SplitQty) next DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,      
                            UOMQTY = CASE UOM WHEN '6' THEN @n_CurQty ELSE UOMQty END ,     
                            DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey      
  
                        IF @@ERROR <> 0       
                        BEGIN  
                           ROLLBACK TRAN     
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END  

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,
                            DropID = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey  
                     END      
                     ELSE      
                     BEGIN      
                        -- Full Pickdetail item Qty for the DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey    
    
                        IF @@ERROR <> 0       
                        BEGIN      
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END   

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set DropID   = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,    
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey       
                     END  -- @n_CurQty <> @n_QtyPick          
                  END  -- @n_CurQty > 0      
                  ELSE -- @n_CurQty = 0
                    SELECT @n_rowid1 = @n_rowid1 - 1  -- Whole pickdetail line cannot fit reculculate with new pallet id

               END  -- WHILE 1=1 
               SET ROWCOUNT 0 
               -- Generate DropID if not data found

		      END  -- WHILE 1=1 
            DROP Table #TEMPPICK1234

         END  
         ----------------------------------------------------------------------------         
         /* END @c_ConfigKey = 'PID_PG1234'                                        */
         ----------------------------------------------------------------------------

      END  -- @c_ConfigKey = 'PID_CTZN' 
      ELSE 
      BEGIN
         SELECT @c_ConfigKey = StorerConfig.ConfigKey, 
                @c_SValue = StorerConfig.SValue 
         FROM #TEMPPICKDETAIL (NOLOCK)
         JOIN StorerConfig (NOLOCK) on ( StorerConfig.StorerKey = #TEMPPICKDETAIL.StorerKey ) 
                                     AND StorerConfig.ConfigKey = 'PID_CONSGN'  

         IF @c_debug = '1'      
         BEGIN      
            SELECT '3. @c_ConfigKey=' + @c_ConfigKey + ' @c_SValue=' + @c_SValue
         END

         IF @c_ConfigKey = 'PID_CONSGN' AND @c_SValue = '1'
         BEGIN 

            SELECT @c_ConsigneeKey = ''
            SELECT @c_row = '0'

            CREATE TABLE #TEMPPICK (
	         Rowid			    int IDENTITY(1,1),
	         ConsigneeKey    NVARCHAR(15),
            PickslipNo		 NVARCHAR(10) NULL)

		      INSERT INTO #TEMPPICK (ConsigneeKey, PickslipNo) 
            SELECT ConsigneeKey, MAX(PickslipNo)
            FROM #TEMPPICKDETAIL (NOLOCK)
            GROUP BY ConsigneeKey
            ORDER BY ConsigneeKey

            IF @c_debug = '1'      
            BEGIN      
               SELECT * FROM #TEMPPICK (NOLOCK)
            END

		      SELECT @n_rowid = 0 		
   	
            WHILE 1=1 
            BEGIN
			      SELECT @n_rowid = Min(rowid) 
			        FROM #TEMPPICK 	
			       WHERE Rowid > @n_rowid

			      IF @n_rowid IS NULL OR @n_rowid = 0 BREAK				

			      Select @c_ConsigneeKey = ConsigneeKey, 
                      @c_PickslipNo = PickslipNo
			        from #TEMPPICK 
			       Where Rowid = @n_rowid

               IF (@c_firsttime = 'N' AND ISNULL(@c_PickslipNo, '') = '') --re-allocation use the existing pickslipno
               BEGIN
                   SELECT @c_PickSlipNo = pickheaderkey, @c_pickheaderkey = pickheaderkey
                   FROM PickHeader (NOLOCK) 
                   WHERE ExternOrderKey = @c_refkey 
                   AND Zone = 'XD'
               END

               IF ISNULL(@c_PickslipNo, '') = ''
               BEGIN
			         EXECUTE nspg_GetKey 
				         'PICKSLIP',
				         8,   
				         @c_pickheaderkey     OUTPUT,
				         @b_success   	      OUTPUT,
				         @n_err       	      OUTPUT,
				         @c_errmsg    	      OUTPUT
      				
			         IF @n_err <> 0 
			         BEGIN
				         select @n_continue = 3
				         Break 
			         END
      				
			         IF @c_type = 'P' 
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END
			         ELSE
			         BEGIN
				         SELECT @c_pickheaderkey = 'PX' + @c_pickheaderkey
			         END  -- @c_type = 'P' 
      				
			         select @c_row = Convert(char(10), convert(int, @c_row) + 1) 

                  IF @c_debug = '1'      
                  BEGIN      
                     SELECT '@c_ConsigneeKey=' + @c_ConsigneeKey + ' @c_pickheaderkey =' + @c_pickheaderkey 
                  END

                  BEGIN TRAN 

			         INSERT INTO PICKHEADER (PickHeaderKey,    WaveKey,    ExternOrderKey, PickType, Zone, TrafficCop)
			         VALUES (@c_pickheaderkey, @c_row, @c_refkey,     '0',      'XD',  '')

                  IF @@ERROR = 0 
                  BEGIN
                     WHILE @@TRANCOUNT > 0 
                        COMMIT TRAN 
                  END 	
                  ELSE
                  BEGIN
                     ROLLBACK TRAN 
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63331   
      		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PickHeader Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                     BREAK 
                  END  -- @@ERROR = 0 

                  IF @n_continue = 1 OR @n_continue = 2
                  BEGIN
				         BEGIN TRAN 

                     UPDATE #TEMPPICKDETAIL 
                        SET PICKSLIPNO = @c_pickheaderkey 
                        FROM  #TEMPPICKDETAIL
                        WHERE ConsigneeKey = @c_ConsigneeKey 
         	
				         SELECT @n_err = @@ERROR
      			
                     IF @n_err = 0 
                     BEGIN
                        WHILE @@TRANCOUNT > 0 
                           COMMIT TRAN 
                     END 	
                     ELSE
                     BEGIN
                        ROLLBACK TRAN 
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63332   
         		         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update PickDetail Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
					         Break
                     END  -- @n_err = 0 

                     IF @c_debug = '1'      
                     BEGIN      
                        SELECT PICKSLIPNO
                        FROM #TEMPPICKDETAIL 
                        WHERE ConsigneeKey = @c_ConsigneeKey 
                     END

                  END  -- @n_continue = 1 OR @n_continue = 2
               END  -- ISNULL(@c_PickslipNo, '') = ''
               ELSE
                  SELECT @c_pickheaderkey = @c_PickslipNo 

               -- Generate DropID if not data found 
               SELECT @n_rowid1         = 0 
               SELECT @b_break          = '0'  
               SELECT @c_BreakKey       = ''
               SELECT @c_prev_BreakKey  = ''               
               SELECT @b_newgroup       = '0'      

               SET ROWCOUNT 1 		
               WHILE 1=1 
               BEGIN
                  SELECT @c_PICKDETAILKey = ''
                  SELECT @d_DeliveryDate = ''  
                  SELECT @c_sku = ''  
                  SELECT @n_StdGrossWGT = ''  
                  SELECT @n_STDCube = ''  
                  SELECT @n_QtyPick = 0 
                  SELECT @c_CartonType = '' 
                  SELECT @n_MaxWeight = '' 
                  SELECT @n_MaxCube = '' 
	                SELECT @n_casecnt = 0      
                  SELECT @n_innerpack = 0               
                  SELECT @c_uom = ''

                  SELECT @n_rowid1        = #TEMPPICKDETAIL.rowid, 
                         @c_PICKDETAILKey = #TEMPPICKDETAIL.PICKDETAILKey, 
                         @c_ConsigneeKey  = #TEMPPICKDETAIL.ConsigneeKey,
                         @d_DeliveryDate  = #TEMPPICKDETAIL.DeliveryDate,
                         @c_sku           = SKU.SKU,      
                         @n_StdGrossWGT   = ISNULL(SKU.StdGrossWGT,0),           
                         @n_STDCube       = ISNULL(SKU.STDCube,0),      
                         @n_QtyPick       = ISNULL(#TEMPPICKDETAIL.Qty,0), 
                         @c_CartonType    = Cartonization.CartonType,
                         @n_MaxWeight     = ISNULL(Cartonization.MaxWeight,0),      
                         @n_MaxCube       = ISNULL(Cartonization.[Cube],0),          
                         @n_CaseCnt       = PACK.casecnt,
                         @n_Innerpack     = PACK.innerpack,
                         @c_uom           = #TEMPPICKDETAIL.uom
                  FROM #TEMPPICKDETAIL (NOLOCK)
                  JOIN SKU     (NOLOCK) ON ( #TEMPPICKDETAIL.Storerkey = SKU.StorerKey ) 
                                             AND ( #TEMPPICKDETAIL.Sku = SKU.Sku )
                  JOIN Storer (NOLOCK) on ( Storer.StorerKey = #TEMPPICKDETAIL.StorerKey )      
                  JOIN Cartonization (NOLOCK) on ( Cartonization.CartonizationGroup = Storer.CartonGroup )  
                                             AND ( Cartonization.CartonType = CASE #TEMPPICKDETAIL.UOM WHEN '1' THEN 'Pallet' WHEN '2' THEN 'Pallet' ELSE 'Tote' END )  
                  JOIN Pack (NOLOCK) ON ( #TEMPPICKDETAIL.Packkey = Pack.Packkey)
	               Where ISNULL(#TEMPPICKDETAIL.Qty,0) >= 0      
                  AND   LEN(ISNULL(#TEMPPICKDETAIL.DropID, '')) = 0       
                  AND   SKU.StdGrossWGT <= Cartonization.MaxWeight    -- Not process for wrong setup,  cartonization weight/cube is less then SKU QTY 1     
                  AND   SKU.STDCube <=  Cartonization.[Cube]  
                  AND   (SKU.StdGrossWGT * PACK.casecnt) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.casecnt) <= Cartonization.[Cube]
                  AND   (SKU.StdGrossWGT * PACK.innerpack) <= Cartonization.MaxWeight
                  AND   (SKU.STDCube * PACK.innerpack) <= Cartonization.[Cube]
                  AND   #TEMPPICKDETAIL.Rowid >= @n_rowid1
                  AND   #TEMPPICKDETAIL.ConsigneeKey = @c_ConsigneeKey
                  Order by #TEMPPICKDETAIL.rowid

                  IF @c_debug = '1'      
                  BEGIN         
                     SELECT '@n_rowid1', @n_rowid1, '@c_ConsigneeKey', @c_ConsigneeKey      
                  END                   

	               IF ISNULL(RTRIM(@n_rowid1), 0) = 0 OR ISNULL(RTRIM(@c_PICKDETAILKey), '') = ''
                  BEGIN
                     BREAK	
                  END			

                  SELECT @c_BreakKey = ISNULL(RTRIM(@c_ConsigneeKey), '') +'/'+ ISNULL(RTRIM(@d_DeliveryDate), '') 

                  IF @c_debug = '1'      
                  BEGIN         
                     SELECT '@c_prev_BreakKey', @c_prev_BreakKey, '@c_BreakKey', @c_BreakKey      
                  END 

                  IF @c_BreakKey <> @c_prev_BreakKey      
                  BEGIN      
                     SELECT @c_prev_breakkey = @c_breakkey      
                     Select @b_break = '1'      
                     SELECT @b_newgroup = '1'      
                  END    

                  -- break DropID      
                  IF  @b_break = '1' 
                  BEGIN 
                     IF @c_debug = '1'      
                     BEGIN        
                        SELECT '@c_CartonType', @c_CartonType       
                        SELECT '@n_MaxWeight', @n_MaxWeight, '@n_MaxCube', @n_MaxCube    
                     END  
                         
                     SELECT @b_getdropid = '1'
                     IF @b_newgroup = '1' and @c_uom <> '1'
                     BEGIN
             	         	BEGIN TRAN               
									      INSERT INTO XDPartialPlt (DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7,
                                 									Col8, Col9, Col10, CumWeight, CumCube)
         								SELECT DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7, 
                							Col8, Col9, Col10, CumWeight, CumCube
	         							FROM #TEMPXDPARTIALPLT
                              
					  		        IF @@ERROR = 0 
    		   							BEGIN
              						WHILE @@TRANCOUNT > 0 
                								COMMIT TRAN 
                				  DELETE FROM #TEMPXDPARTIALPLT
         				    		END -- @@ERROR = 0 	
         							  ELSE
         							  BEGIN 
            						  ROLLBACK TRAN 
            						  SELECT @n_continue = 3
            						  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63353   
          							  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         								END  -- @@ERROR <> 0 
                     	
                        SELECT @n_RowId2 = a.Rowid, @c_DropID = a.DropId, @n_CumWeight = a.CumWeight, @n_CumCube = a.CumCube
                        FROM XDPartialPlt a (NOLOCK), pickdetail b (NOLOCK)
                        WHERE a.Consigneekey = @c_ConsigneeKey
                        AND CONVERT(char(8),a.DeliveryDate,1) = CONVERT(char(8),@d_DeliveryDate,1)
                        AND a.DropId = b.DropId
                        
                        IF @@ROWCOUNT > 0
                        BEGIN
                           SELECT @b_getdropid = '0'
                          
                           BEGIN TRAN
                           DELETE FROM XDPartialPlt WHERE RowId = @n_RowId2
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63388   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END

                        SELECT @b_newgroup = '0'
                     END
                     
                     IF @b_getdropid = '1'
                     BEGIN               
                        EXECUTE nspg_GetKey      
                           'PICKToID',      
                           10,      
                           @c_DropID OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      
   
                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        SELECT @n_CumWeight = 0      
                        SELECT @n_CumCube   = 0 
                     END         
                     SELECT @n_CurQty    = 0    
                     SELECT @n_CapWeight = 0          
                     SELECT @n_CapCube   = 0  
                     SELECT @c_Remark    = ''  
                     SELECT @b_break     = '0'  
                  END

                  SELECT @n_SplitQty = 0      
                  SELECT @n_CurQty   = @n_QtyPick  

                  -- loop decs to fit in Pallet\Tote Weight\Cube      
                  WHILE @n_CurQty > 0      
                  BEGIN      

                   	 IF @c_uom = '1'  -- Full pallet
                  	 BEGIN
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100
                        SELECT @b_break = '1'
                        SELECT @c_remark = 'MAX'
                  	    BREAK
                  	 END
                  	
                     IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) <= @n_MaxWeight AND      
                        @n_CumCube   + ( @n_CurQty * @n_STDCube )     <= @n_MaxCube          
                     BEGIN      
                        SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )       
                        SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )           
                        SELECT @n_Capacity  = @n_CumWeight/@n_MaxWeight*100
                        
                        IF @b_break = '0'
                        BEGIN
                           BEGIN TRAN
                           IF ( ( SELECT COUNT(RowId) FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID ) > 0 )
                              UPDATE #TEMPXDPARTIALPLT SET CumWeight = @n_CumWeight, CumCube = @n_CumCube
                              WHERE DropId = @c_DropID                                                      
                           ELSE                       
                              INSERT INTO #TEMPXDPARTIALPLT (DropId, Consigneekey, DeliveryDate, CumWeight, CumCube)
                                                       VALUES (@c_DropID, @c_ConsigneeKey, @d_DeliveryDate, @n_CumWeight, @n_CumCube)
                           IF @@ERROR = 0 
                           BEGIN
                              WHILE @@TRANCOUNT > 0 
                                 COMMIT TRAN 
                           END -- @@ERROR = 0 	
                           ELSE
                           BEGIN 
                              ROLLBACK TRAN 
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63389   
               	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert/Update #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           END  -- @@ERROR <> 0 
                        END
                        
                        BREAK      
                     END      
                     ELSE      
                     BEGIN      
                     	  IF @c_uom = '2'   -- To ensure a case/inner pack not split to multi PID
                     	  BEGIN
                     	  	 SELECT @n_CurQty = @n_CurQty - @n_casecnt
                     		END                     		
                     	  ELSE
                     	  BEGIN
                     	  	 IF @c_uom = '3'
                        	 		SELECT @n_CurQty = @n_CurQty - @n_innerpack 
                        	 ELSE
                        	 		SELECT @n_CurQty = @n_CurQty - 1      
                        END

                        SELECT @b_break = '1'  -- cause split PickDetail and break Drop ID      
                        IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) > @n_MaxWeight
                        BEGIN
                           SELECT @n_Capacity = @n_CumWeight/@n_MaxWeight*100
                        END 

                        IF @n_CumCube   + ( @n_CurQty * @n_STDCube )     > @n_MaxCube
                        BEGIN
                           SELECT @n_Capacity = @n_CumCube/@n_MaxCube*100
                        END
                        SELECT @c_Remark = 'MAX'
                        BEGIN TRAN                        
                        DELETE FROM #TEMPXDPARTIALPLT WHERE DropId = @c_DropID
                        IF @@ERROR = 0 
                        BEGIN
                           WHILE @@TRANCOUNT > 0 
                              COMMIT TRAN 
                        END -- @@ERROR = 0 	
                        ELSE
                        BEGIN 
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63390   
            	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete #TEMPXDPARTIALPLT Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                        END  -- @@ERROR <> 0 
                     END      
                  END       
               
                  IF @c_debug = '1'      
                  BEGIN        
                     SELECT '@n_CurQty', @n_CurQty       
                     SELECT '@n_CumWeight', @n_CumWeight       
                     SELECT '@n_CumCube', @n_CumCube 
                     SELECT '@c_DropID', @c_DropID          
                  END   
               
                  IF @n_CurQty > 0       
                  BEGIN      
                     IF @n_CurQty <> @n_QtyPick        
                     BEGIN      
                        BEGIN TRAN  
                        SELECT @n_SplitQty = @n_QtyPick  - @n_CurQty      
                  
                        EXECUTE nspg_GetKey      
                           'PICKDETAILKEY',      
                           10,      
                           @c_New_PICKDETAILKey OUTPUT,         
                           @b_success OUTPUT,      
                           @n_err OUTPUT,      
                           @c_errmsg OUTPUT      

                        IF NOT @b_success = 1      
                        BEGIN      
                           BREAK      
                        END      
                  
                        IF @c_debug = '1'      
                        BEGIN        
                           SELECT '@c_New_PICKDETAILKey', @c_New_PICKDETAILKey      
                        END      
                   
                        -- new pick item for remaining @n_SplitQty    
                        INSERT PICKDETAIL      
                           ( PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,       
                           DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo )      
                        SELECT @c_New_PICKDETAILKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                           Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                           '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                           WaveKey, EffectiveDate, '9', ShipFlag, @c_pickheaderkey      
                        FROM PICKDETAIL       
                        WHERE PICKDETAILKey = @c_PICKDETAILKey          
                            
                        IF @@ERROR <> 0     
                        BEGIN     
                           ROLLBACK TRAN  
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + 
                                             ': Insert Into PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END     

			               INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, Storerkey, Sku, Qty, Lot, Loc, ID, Packkey, 
                                                     PickSlipNo, UOM, DropID, ConsigneeKey, C_Company, Priority, DeliveryDate, Capacity, Remark, PrintedFlag)
			               SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.Storerkey, PD.Sku, PD.Qty, PD.Lot, PD.Loc, PD.ID, PD.Packkey, 
                               PD.PickSlipNo, PD.UOM, PD.DropID, OH.CONSIGNEEKEY, OH.C_COMPANY, OH.Priority, OH.DeliveryDate, @n_Capacity, @c_Remark, @c_PrintedFlag
			                 FROM ORDERDETAIL OD (NOLOCK), PICKDETAIL PD (NOLOCK), ORDERS OH (NOLOCK) 
			                WHERE PD.ORDERKEY = OD.ORDERKEY 
				               AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER 
                           AND OH.ORDERKEY = OD.ORDERKEY
				               AND PD.PICKDETAILKey = @c_New_PICKDETAILKey   
                     
                        IF @@ERROR <> 0 
                        BEGIN
                           ROLLBACK TRAN 
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63302   
   		                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert #TEMPPICKDETAIL Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                           BREAK  
                        END  -- @@ERROR <> 0  
             
                        -- existing DROPID carton allow qty (@n_CurQty)   , remaining qty  (@n_SplitQty) next DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,      
                            UOMQTY = CASE UOM WHEN '6' THEN @n_CurQty ELSE UOMQty END ,     
                            DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey      
  
                        IF @@ERROR <> 0       
                        BEGIN  
                           ROLLBACK TRAN     
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END  

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set Qty = @n_CurQty,
                            DropID = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey  
                     END      
                     ELSE      
                     BEGIN      
                        -- Full Pickdetail item Qty for the DropID    
                        Update PICKDETAIL with (ROWLOCK)      
                        Set DropID = @c_DropID,      
                            PickslipNo = @c_pickheaderkey,      
                            TrafficCop = NULL,      
                            AltSku = Convert(char(3),convert(int,round(@n_Capacity,0)))+ @c_remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey    
    
                        IF @@ERROR <> 0       
                        BEGIN      
                           SELECT @n_continue = 3      
                           SELECT @n_err = 63501      
                           SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'      
                           BREAK    
                        END   

                        Update #TEMPPICKDETAIL with (ROWLOCK)      
                        Set DropID   = @c_DropID,
                            Capacity = convert(int,round(@n_Capacity,0)),
                            PickslipNo = @c_pickheaderkey,     
                            Remark = @c_Remark
                        WHERE PICKDETAILKey = @c_PICKDETAILKey       
                     END  -- @n_CurQty <> @n_QtyPick          
                  END  -- @n_CurQty > 0      
                  ELSE -- @n_CurQty = 0
                    SELECT @n_rowid1 = @n_rowid1 - 1  -- Whole pickdetail line cannot fit reculculate with new pallet id

               END  -- WHILE 1=1 
               SET ROWCOUNT 0 
               -- Generate DropID if not data found

		      END  -- WHILE 1=1 
            DROP Table #TEMPPICK
         END  -- @c_ConfigKey = 'PID_CONSGN'
      END  -- @c_ConfigKey <> 'PID_CTZN' 
      
      IF @n_continue = 1 OR @n_continue = 2  
      BEGIN               
         BEGIN TRAN 
              
         INSERT INTO XDPartialPlt (DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7,
                                   Col8, Col9, Col10, CumWeight, CumCube)
         SELECT DropId, ConsigneeKey, DeliveryDate, Col1, Col2, Col3, Col4, Col5, Col6, Col7, 
                Col8, Col9, Col10, CumWeight, CumCube
         FROM #TEMPXDPARTIALPLT
                              
         IF @@ERROR = 0 
         BEGIN
            WHILE @@TRANCOUNT > 0 
               COMMIT TRAN 
         END -- @@ERROR = 0 	
         ELSE
         BEGIN 
            ROLLBACK TRAN 
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63353   
          	SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert XDPartialPlt Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         END  -- @@ERROR <> 0 
      END

	   IF @c_firsttime = 'Y'
	   BEGIN
		   IF @n_continue = 1 OR @n_continue = 2  
		   BEGIN 
            BEGIN TRAN 
		
			   UPDATE PICKDETAIL 
				   SET PICKDETAIL.TRAFFICCOP = NULL, 
					    PICKDETAIL.PICKSLIPNO = #TEMPPICKDETAIL.PICKSLIPNO, 
                   PICKDETAIL.DropID     = #TEMPPICKDETAIL.DropID 
			     FROM PICKDETAIL (NOLOCK)
              JOIN #TEMPPICKDETAIL (NOLOCK) ON (PICKDETAIL.PICKDETAILKEY = #TEMPPICKDETAIL.PICKDETAILKEY)
		
			   SELECT @n_err = @@ERROR
		
            IF @n_err = 0 
            BEGIN
               WHILE @@TRANCOUNT > 0 
                  COMMIT TRAN 
            END 	
            ELSE
            BEGIN
               ROLLBACK TRAN 
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63333   
      		   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update PickDetail Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
            END  -- @n_err = 0 

			   --Select @c_row = '0'

            BEGIN TRAN 
	
			   INSERT INTO RefKeyLookup (OrderKey, OrderLinenumber, Pickslipno, Pickdetailkey)
			   SELECT OrderKey, OrderLinenumber, Pickslipno, Pickdetailkey FROM #TEMPPICKDETAIL 
			   Order BY Pickdetailkey 

            IF @c_debug = '1'      
            BEGIN      
               SELECT 'PICKDETAIL',PICKDETAIL.PICKSLIPNO
               FROM PICKDETAIL (NOLOCK)
               JOIN #TEMPPICKDETAIL (NOLOCK) ON (PICKDETAIL.PICKDETAILKEY = #TEMPPICKDETAIL.PICKDETAILKEY)
            
               SELECT 'RefKeyLookup', * FROM RefKeyLookup (NOLOCK) 
               JOIN #TEMPPICKDETAIL (NOLOCK) ON (RefKeyLookup.Pickdetailkey = #TEMPPICKDETAIL.Pickdetailkey)
            END

			   SELECT @n_err = @@ERROR
            IF @n_err = 0 
            BEGIN
               WHILE @@TRANCOUNT > 0 
                  COMMIT TRAN 
            END 	
            ELSE
            BEGIN
               ROLLBACK TRAN 
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63334   
      		   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into RefKeyLookup Failed. (nsp_GetPickSlipXD08)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
            END  -- @n_err = 0 
		   END  
	   END  -- @c_firsttime = 'Y'

		IF @n_continue = 1 OR @n_continue = 2 
		BEGIN 
			IF @c_type <> 'P' 
			BEGIN 
				SELECT @c_refkey = (SELECT DISTINCT OD.EXTERNPOKEY 
										   FROM ORDERDETAIL OD (NOLOCK), #TEMPPICKDETAIL 
				 						  WHERE OD.ORDERKEY = #TEMPPICKDETAIL.ORDERKEY 
										    AND OD.ORDERLINENUMBER = #TEMPPICKDETAIL.ORDERLINENUMBER)
			END  -- @c_type <> 'P' 		
	
			SELECT @c_recvby = (SELECT MAX(EDITWHO) 
						 		 		FROM RECEIPTDETAIL (NOLOCK) 
									  WHERE EXTERNRECEIPTKEY = @c_refkey)


         WHILE @@TRANCOUNT > 0 
            COMMIT TRAN 

			SELECT #TEMPPICKDETAIL.*, ISNULL(SKU.DESCR,'') SKUDESCR, OD.EXTERNPOKEY, STORERSODEFAULT.XDockLane,  STORERSODEFAULT.XDockRoute, 
					 ISNULL(PACK.Casecnt, 0) CASECNT, ISNULL(PACK.Innerpack, 0) Innerpack, @c_recvby 
					 , ISNULL(PO.POTYPE , '') POTYPE, SKU.SUSR3, SKU.Class, STORER.Company
			  FROM #TEMPPICKDETAIL JOIN ORDERDETAIL OD WITH (NOLOCK)
					ON OD.ORDERKEY = #TEMPPICKDETAIL.ORDERKEY 
					AND OD.ORDERLINENUMBER = #TEMPPICKDETAIL.ORDERLINENUMBER
			-- Add by June 30.June.2004, dun display P/S records when Pickheader rec not successfully inserted 
			  LEFT JOIN PICKHEADER PH (NOLOCK) ON PH.Pickheaderkey = #TEMPPICKDETAIL.PickslipNo 
			  JOIN SKU WITH (NOLOCK)
					ON #TEMPPICKDETAIL.STORERKEY = SKU.STORERKEY 
					AND #TEMPPICKDETAIL.SKU = SKU.SKU 
			  JOIN PACK WITH (NOLOCK) 
					ON SKU.PACKKEY = PACK.PACKKEY
			  LEFT OUTER JOIN STORER WITH (NOLOCK)
					ON STORER.STORERKEY = SKU.SUSR3 
				LEFT OUTER JOIN STORERSODEFAULT 
					ON STORER.STORERKEY = STORERSODEFAULT.STORERKEY 
				--LEFT JOIN PO (NOLOCK) ON OH.ExternPOKey = PO.ExternPOkey 		-- ONG01
				LEFT JOIN PO (NOLOCK) ON OD.ExternPOKey = PO.ExternPOkey 		-- SOS#79918
                                   AND #TEMPPICKDETAIL.STORERKEY = PO.Storerkey         -- TLTING
			ORDER BY #TEMPPICKDETAIL.PICKSLIPNO, #TEMPPICKDETAIL.SKU, #TEMPPICKDETAIL.PRIORITY, #TEMPPICKDETAIL.CONSIGNEEKEY  
	   END  
	END  

	DROP Table #TEMPPICKDETAIL  
   DROP Table #TEMPXDPARTIALPLT

   IF @n_continue=3
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_GetPickSlipXD08'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END 
END

GO