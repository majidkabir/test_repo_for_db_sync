SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_URN_Carton_Label                               */
/* Creation Date: 20-APR-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: URN Carton Label                                            */
/*                                                                      */
/* Called By: nep_w_loadplan_maintenance                                */ 
/*                                                                      */
/* Parameters: (Input)  @c_loadKey   = Load Number                      */
/*                                                                      */
/* PVCS Version: 1.0	                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 23-Aug-2009  James     1.1   SOS145871 - Insert PackDetail (james01) */
/* 26-Aug-2009  James     1.2   SOS146207 - Change URN ncounter to      */
/*                              Intermodalvehicle (james02)             */
/* 03-Mar-2010  GTGOH     1.3   SOS162593 - Print UPC from SKU.AltSKU   */
/*                                          (Goh01)                     */
/* 03-Dec-2018  GTGOH     1.4   Missing nolock                          */
/* 28-Jan-2019  TLTING_ext 1.5  enlarge externorderkey field length     */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_URN_Carton_Label]
   @c_LoadKey   NVARCHAR(10)
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
			  @b_success  int,
    		  @n_err      int,
   		  @c_errmsg   NVARCHAR(225),
           @n_cnt int,
           @n_cnt2 int
           
   DECLARE @n_RowId int,
           @n_RowId2 int,
           @c_keyname           NVARCHAR(30),
           @c_ConsigneeKey      NVARCHAR(15),
           @c_externorderkey    NVARCHAR(50),  --tlting_ext
           @c_ItemClass         NVARCHAR(10),
           @c_Busr5             NVARCHAR(30),
           @c_company           NVARCHAR(45),
           @c_IntermodalVehicle NVARCHAR(30),
           @n_qty               int,
           @n_totalcase         int,
           @n_totalpallet       int,
           @n_packqty           int,
           @c_urnno             NVARCHAR(6),
           @c_labelname         NVARCHAR(45),
           @c_facility          NVARCHAR(5),
           @n_casecnt           float,
           @n_pallet            float,
           @cPickSlipNo         NVARCHAR(10),  --(james01)
           @cPickSlipType       NVARCHAR(10),  --(james01)
           @nCartonNo           int,       --(james01)
           @cLabelLine          NVARCHAR(5),   --(james01)
           @cSKU                NVARCHAR(20),  --(james01)
           @cStorerKey          NVARCHAR(15),  --(james01)
           @nCaseNeeded         int,       --(james01)
           @nPackDtlCount       int,       --(james01)
           @nTranCount          int,       --(james01)
           @nRecCount           int,       --(james01)
           @cBUSR3              NVARCHAR(30),  --(james01)
           @cURNNo              NVARCHAR(32),  --(james01)
			  @c_altsku		        NVARCHAR(20)	--GOH01
           

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN URN_Label

   SELECT @n_Continue = 1, @b_success = 1, @c_errmsg='', @n_err=0 

   CREATE TABLE #URNLABEL (
         consigneeKey      NVARCHAR(15) NULL,
         externorderkey    NVARCHAR(50) NULL,  --tlting_ext
         itemclass         NVARCHAR(10) NULL,
         busr5             NVARCHAR(30) NULL,
         company           NVARCHAR(45) NULL,
         intermodalvehicle NVARCHAR(30) NULL,
         qty               int NULL,
         urnno             NVARCHAR(6) NULL,
         labelname         NVARCHAR(45) NULL,
			altsku			 NVARCHAR(20) NULL )	--GOH01
	
   IF @n_continue = 1 or @n_continue=2
   BEGIN
      --(james01)
      IF EXISTS (SELECT 1 FROM Orders (NOLOCK) WHERE LoadKey = @c_LoadKey AND STATUS = '9')
      BEGIN
         SET @n_continue=3
         SET @n_err = 50001
         SET @c_ErrMsg = 'Orders already closed, not allow to reprint URN label. (isp_URN_Carton_Label)'
         GOTO Quit
      END

      --(james01)
      SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader (NOLOCK) 
      WHERE ExternOrderKey = @c_LoadKey

      --(james01)
      SELECT TOP 1 @cStorerKey = StorerKey FROM Orders (NOLOCK) 
      WHERE LoadKey = @c_LoadKey

      -- Determine pickslip type, either Discrete/Consolidated
	   IF EXISTS (SELECT 1 
         FROM PickHeader PH WITH (NOLOCK)
	      JOIN PickingInfo PInfo (NOLOCK) ON (PInfo.PickSlipNo = PH.PickHeaderKey) 
	      LEFT OUTER JOIN ORDERS O WITH (NOLOCK) ON (O.OrderKey = PH.OrderKey)
	      WHERE PH.PickHeaderKey = @cPickSlipNo)
         SET @cPickSlipType = 'CONSO'
	   ELSE
		   SET @cPickSlipType = 'SINGLE'

      SELECT IDENTITY(int,1,1) AS Rowid, ORDERS.Consigneekey, ORDERS.Externorderkey, SKU.Itemclass, SKU.Busr5
      INTO #TMPCARTONGROUP
      FROM ORDERS (NOLOCK)
      JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
      JOIN SKU (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku)
      JOIN LOADPLANDETAIL (NOLOCK) ON  (ORDERS.Orderkey = LOADPLANDETAIL.Orderkey)
      WHERE LOADPLANDETAIL.Loadkey = @c_loadkey
      GROUP BY ORDERS.Consigneekey, ORDERS.Externorderkey, SKU.Itemclass, SKU.Busr5
      ORDER BY ORDERS.Consigneekey, ORDERS.Externorderkey, SKU.Itemclass, SKU.Busr5

      SELECT @nRecCount = COUNT(1) FROM #TMPCARTONGROUP 
      IF @nRecCount > 0
      BEGIN
         IF EXISTS (SELECT 1 FROM PackDetail (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
         BEGIN
            DELETE FROM PackDetail WHERE PickSlipNo = @cPickSlipNo

            IF @@ERROR <> 0
            BEGIN
	 	         SELECT @n_continue=3
               GOTO RollBackTran
            END
         END

         IF EXISTS (SELECT 1 FROM Packinfo (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
         BEGIN
            DELETE FROM Packinfo WHERE PickSlipNo = @cPickSlipNo

            IF @@ERROR <> 0
            BEGIN
	 	         SELECT @n_continue=3
               GOTO RollBackTran
            END
         END
      END

      SELECT @n_rowid = 0      
			WHILE 1=1 
 			BEGIN
	      SET ROWCOUNT  1  	

     	  SELECT @n_rowid = rowid,
     	         @c_consigneekey = consigneekey,
     	         @c_externorderkey = externorderkey,
     	         @c_itemclass = itemclass,
     	         @c_busr5 = busr5
	   	  FROM #TMPCARTONGROUP
	   	  WHERE rowid > @n_rowid
	   	  ORDER BY rowid
	   	          
        SELECT @n_cnt = @@ROWCOUNT
	
	      SET ROWCOUNT  0
	      IF @n_cnt = 0
	      	 BREAK
        
      	SELECT IDENTITY(int,1,1) AS Rowid, STORER.Company, ORDERS.IntermodalVehicle, PACK.casecnt, 
      	       SUM(ORDERDETAIL.qtyallocated + ORDERDETAIL.qtypicked + ORDERDETAIL.shippedqty) AS qty,
      	       CONVERT(int,CEILING(CASE WHEN PACK.casecnt > 0 THEN SUM(ORDERDETAIL.qtyallocated + ORDERDETAIL.qtypicked + ORDERDETAIL.shippedqty) / PACK.casecnt ELSE 0 END)) AS totalcase,
      	       CONVERT(int,FLOOR(CASE WHEN PACK.pallet > 0 THEN SUM(ORDERDETAIL.qtyallocated + ORDERDETAIL.qtypicked + ORDERDETAIL.shippedqty) / PACK.pallet ELSE 0 END)) AS totalpallet,
      	       LB.Company AS labelname, ORDERS.Facility, ORDERDETAIL.SKU, PACK.pallet
					 , SKU.AltSKU	--GOH01
      	INTO #TMPCARTONPACK
 	      FROM ORDERS (NOLOCK)
	      JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
   		  JOIN SKU (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku)
   		  JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   		  LEFT JOIN STORER (NOLOCK) ON (SKU.Busr5 = STORER.Storerkey)
   		  JOIN STORER LB (NOLOCK) ON (ORDERS.Consigneekey = LB.Storerkey)
     		JOIN LOADPLANDETAIL (NOLOCK) ON  (ORDERS.Orderkey = LOADPLANDETAIL.Orderkey)
     		WHERE LOADPLANDETAIL.Loadkey = @c_loadkey
     		AND ORDERS.Consigneekey = @c_consigneekey
     		AND ORDERS.Externorderkey = @c_externorderkey
     		AND SKU.Itemclass = @c_itemclass
     		AND SKU.Busr5 = @c_busr5
     		GROUP BY STORER.Company, ORDERS.IntermodalVehicle, PACK.casecnt, LB.Company, ORDERS.Facility, ORDERDETAIL.SKU, PACK.Pallet
			, SKU.AltSKU	--GOH01
     		ORDER BY ORDERDETAIL.SKU

        SELECT @n_rowid2 = 0   	 
	      WHILE 1=1
	      BEGIN
	          
     	  	 SELECT TOP 1 @n_rowid2 = rowid,
     	         @c_company = company,
     	         @c_intermodalvehicle = ISNULL(RTRIM(intermodalvehicle),''),
     	         @n_qty = qty,
     	         @n_totalcase = totalcase,
     	         @n_totalpallet = totalpallet,
     	         @c_labelname = labelname,
     	         @c_facility = ISNULL(RTRIM(facility),''),
     	         @n_casecnt = casecnt,
     	         @n_pallet = pallet,
               @cSKU = SKU
					,@c_altsku = AltSKU	--GOH01           
		   	   FROM #TMPCARTONPACK
	   	  	 WHERE rowid > @n_rowid2
	   	  	 ORDER BY rowid
	   	          
           SELECT @n_cnt2 = @@ROWCOUNT
	 
	      	 IF @n_cnt2 = 0
	      	    BREAK
	      	    
	      	 IF @n_totalpallet > 0 AND @n_totalcase > 0
	      	 BEGIN
	      	 	  SELECT @n_totalcase = @n_totalcase - (@n_totalpallet * @n_pallet / @n_casecnt)
	      	 END
	      	 	      	 
	      	 WHILE (@n_totalpallet + @n_totalcase) > 0
	      	 BEGIN
	    	  	 	SELECT @n_packqty = 0
	    	  	 	
--              SELECT @c_keyname = @c_facility+'_'+@c_intermodalvehicle   (james02)
               SELECT @c_keyname = @c_intermodalvehicle   --(james02)

  	 		 	    EXECUTE dbo.nspg_getkey
		           @c_keyname
    		      , 6
         		  , @c_urnno OUTPUT
           		, @b_success OUTPUT
           		, @n_err OUTPUT
           		, @c_errmsg OUTPUT

        			IF NOT @b_success=1
				      BEGIN
           		 	SELECT @n_continue=3
           			BREAK
        			END              

	      		  IF @n_totalpallet > 0
	      		  BEGIN
	      		  	 SELECT @n_totalpallet = @n_totalpallet - 1
	      		  	 SELECT @n_packqty = @n_pallet
	      		  	 SELECT @n_qty = @n_qty - @n_pallet
	      		  END
	      		  ELSE
	      		  BEGIN
	      		  	 IF @n_totalcase > 0
	      		  	 BEGIN
	      		  	 	  SELECT @n_totalcase = @n_totalcase - 1
	      		  	 	  IF @n_qty >= @n_casecnt
	      		  	 	  BEGIN
	      		  	 	  	 SELECT @n_packqty = @n_casecnt
	      		  	 	  	 SELECT @n_qty = @n_qty - @n_casecnt
	      		  	 	  END
	      		  	 	  ELSE
	      		  	 	  BEGIN
	      		  	 	  	 SELECT @n_packqty = @n_qty
	      		  	 	  	 SELECT @n_qty = 0
   	      		  	 	END     		  	 	  
	      		  	 END
	      		  END

               SELECT @nCaseNeeded = (SUM(PD.QTY)/PACK.CaseCNT) FROM PickDetail PD (NOLOCK) 
               JOIN Orders O (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               JOIN SKU SKU (NOLOCK) ON (PD.SKU = SKU.SKU)
               JOIN PACK PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
               WHERE O.StorerKey = @cStorerKey
                  AND O.LoadKey = @c_LoadKey
                  AND PD.SKU = @cSKU
               GROUP BY PACK.CaseCNT

               SELECT @nPackDtlCount = COUNT(1) FROM PackDetail (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               AND SKU = @cSKU
 
               IF @nCaseNeeded > @nPackDtlCount
               BEGIN
                  -- Check whether packheader exists
                  IF NOT EXISTS (SELECT 1 FROM PACKHEADER WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
                  BEGIN
                     -- Conso Pickslipno
                     IF @cPickSlipType = 'CONSO'
                     BEGIN
                        INSERT INTO PackHeader 
                        (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
                        SELECT DISTINCT ISNULL(LP.Route,''), '', '', LP.LoadKey, '', @cStorerKey, @cPickSlipNo
                        FROM  LOADPLANDETAIL LPD WITH (NOLOCK)
                        JOIN  LOADPLAN LP WITH (NOLOCK) ON (LP.LoadKey = LPD.LoadKey)
                        JOIN  ORDERS O WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
                        JOIN  PICKHEADER PH WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
                        WHERE PH.PickHeaderKey = @cPickSlipNo

                        IF @@ERROR <> 0
                        BEGIN
                           SELECT @n_continue=3
                           GOTO RollBackTran
                        END
                     END   -- @cPickSlipType = 'CONSO'
                     ELSE
                     BEGIN
                        INSERT INTO PackHeader 
                        (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
                        SELECT O.Route, O.OrderKey, O.ExternOrderKey, O.LoadKey, O.ConsigneeKey, O.Storerkey, @cPickSlipNo 
                        FROM  PickHeader PH WITH (NOLOCK)
                        JOIN  Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)
                        WHERE PH.PickHeaderKey = @cPickSlipNo

                        IF @@ERROR <> 0
                        BEGIN
                           SELECT @n_continue=3
                           GOTO RollBackTran
                        END
                     END   -- @cPickSlipType = 'SINGLE'
                  END   -- Check whether packheader exists

                  EXECUTE dbo.nspg_getkey
                  'URNLABEL'
                  , 10
                  , @nCartonNo OUTPUT
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

                  IF NOT @b_success=1
                  BEGIN
                     SELECT @n_continue=3
                     GOTO RollBackTran
                  END          

                  SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
                  FROM PackDetail WITH (NOLOCK)
                  WHERE Pickslipno = @cPickSlipNo
                     AND CartonNo = @nCartonNo

                     -- Insert PackDetail
                     INSERT INTO PackDetail 
                        (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate)
                     VALUES 
                        (@cPickSlipNo, @nCartonNo, @c_urnno, @cLabelLine, @cStorerKey, @cSKU, @n_packqty, sUser_sName(), GETDATE(), sUser_sName(), GETDATE())

                     IF @@ERROR <> 0
                     BEGIN
           		 	      SELECT @n_continue=3
                        GOTO RollBackTran
        			      END  

                     IF NOT EXISTS (SELECT 1 FROM PackInfo (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
                     BEGIN
                        SELECT @cBUSR3 = RTRIM(SKU.BUSR3)
                        FROM SKU (NOLOCK) WHERE SKU = @cSKU AND Storerkey = @cStorerKey

                        SET @cURNNo = LEFT(@c_consigneekey,4) + LEFT(@c_intermodalvehicle,3) + LEFT(@c_urnno,6) +
                                 ISNULL(LEFT(@c_busr5,5),'') + RIGHT('000'+RIGHT(ISNULL(RTRIM(@c_itemclass),''),3),3) + 
                                 LEFT(@c_externorderkey,6) + RIGHT('000'+RTRIM(CONVERT(char(3),@n_packqty)),3) + '01'

                        -- Insert PackInfo
                        INSERT INTO PackInfo
                          (PickSlipNo, CartonNo, AddWho, AddDate, EditWho, EditDate, CartonType, RefNo)
                        VALUES 
                          (@cPickSlipNo, @nCartonNo, sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), @cBUSR3, RTRIM(@cURNNo))

                        IF @@ERROR <> 0
                        BEGIN
           		 	         SELECT @n_continue=3
                           GOTO RollBackTran
        			         END  
                     END
               END
	      		  	      		  	 
     		  	  INSERT INTO #URNLABEL (consigneeKey, externorderkey, itemclass, busr5,
         			                       company, intermodalvehicle, qty, urnno, labelname, altsku)	--GOH01
         		         VALUES (@c_consigneekey, @c_externorderkey, @c_itemclass, @c_busr5,
         				             @c_company, @c_intermodalvehicle, @n_packqty, @c_urnno, @c_labelname, @c_altsku)	--GOH01

	      	 END -- end while 3 (@n_totalpallet + @n_totalcase)> 0	      	 
	      END --end while 2 qty	       	 	  

        DROP TABLE #TMPCARTONPACK 
     END --while carton group    
   END -- @n_continue = 1 or @n_continue=2
   
   IF @n_continue=1 OR @n_continue=2
   BEGIN
   	  
   	  SELECT 1 AS pkgno, a.consigneeKey, a.externorderkey, a.itemclass, a.busr5,
         		 a.company, a.intermodalvehicle, a.qty, a.urnno, 1 AS totalpkgs,
         		 (LEFT(a.consigneekey,4)+LEFT(a.intermodalvehicle,3)+LEFT(a.urnno,6)+
         		 ISNULL(LEFT(a.busr5,5),'')+RIGHT('000'+RIGHT(ISNULL(RTRIM(a.itemclass),''),2),3)+
         		 LEFT(a.externorderkey,6)+RIGHT('000'+RTRIM(CONVERT(char(3),a.qty)),3)+'01') AS labelcode,
         		 (LEFT(a.consigneekey,4)+' '+LEFT(a.intermodalvehicle,3)+' '+LEFT(a.urnno,6)+' '+
         		 ISNULL(LEFT(a.busr5,5),'')+' '+RIGHT('000'+RIGHT(ISNULL(RTRIM(a.itemclass),''),2),3)+' '+
         		 LEFT(a.externorderkey,6)+' '+
         		 RIGHT('000'+RTRIM(CONVERT(char(3),a.qty)),3)+' '+'01') AS labelcodehr,
         		 a.labelname
					 , a.altsku		--GOH01
      FROM #URNLABEL a 
      ORDER BY a.consigneeKey, a.externorderkey, a.itemclass, a.busr5,
         		   a.company, a.intermodalvehicle         		   
   END

   GOTO Quit   

   RollBackTran:
      ROLLBACK TRAN URN_Label

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN URN_Label
      
   IF @n_continue=3  -- Error Occured - Process And Return
	 BEGIN
  	  execute nsp_logerror @n_err, @c_errmsg, 'isp_URN_Carton_Label'
	    RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
	    RETURN
	 END

END -- End PROC

GO