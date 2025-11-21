SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* SP: ispPopulateToASN_NIKECRW                                           */
/* Creation Date: 26-Jul-2017                                             */
/* Copyright: LF                                                          */
/* Written by: Wendy Wang             						                        */
/*                                                                        */
/* Purpose:                                                               */
/*                                                                        */
/* Input Parameters: Orderkey                                             */
/*                                                                        */
/* Output Parameters: NONE                                                */
/*                                                                        */
/* Return Status: NONE                                                    */
/*                                                                        */
/* Usage:                                                                 */
/*                                                                        */
/* Local Variables:                                                       */
/*                                                                        */
/*                                                                        */
/* Called By: ntrMBOLHeaderUpdate                                         */
/*                                                                        */
/* PVCS Version: 1.0                                                      */
/*                                                                        */
/* Version: 5.4                                                           */
/*                                                                        */
/* Data Modifications:                                                    */ 
/*                                                                        */
/*                                                                        */
/* Updates:                                                               */
/*Date         Author  Ver. Purposes                                      */
/*25 Dec 2017  Wendy   1.1  Bug Fixed            wwang01                  */
/*10 Jan 2018  Wendy   1.2  C/R WMS-3762         wwang02                  */
/*22 Mar 2018  Wendy   1.3  C/R WMS-4416         wwang03/wwang04          */
/**************************************************************************/
--EXEC  ispPopulateToASN_NIKECRW '0065063860'

CREATE PROCEDURE [dbo].[ispPopulateToASN_NIKECRW] 
   @c_OrderKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON			
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE @c_ExternReceiptKey    NVARCHAR(20),
          @c_SKU                 NVARCHAR(20),
          @c_PackKey             NVARCHAR(10),
          @c_UOM                 NVARCHAR(5),
			    @c_SKUGroup            NVARCHAR(10),
			    @c_ItemClass           NVARCHAR(10),
          @c_StorerKey           NVARCHAR(15),
          @c_ToStorerKey         NVARCHAR(15),
          @c_ToFacility          NVARCHAR(5),
		      @c_ID				           NVARCHAR(18),
		      @c_ToLoc		           NVARCHAR(10),
		      @c_Type                NVARCHAR(10),
		      @c_WarehouseReference  NVARCHAR(18),
			    @c_ReceiptGroup        NVARCHAR(20),
			    @c_Site                NVARCHAR(10),  --wwang03
			    @c_DocType             NCHAR(1)
                                                                     
   DECLARE @c_NewReceiptKey       NVARCHAR(10),
           @c_ReceiptLine         NVARCHAR(5),
           @n_LineNo              INT,
           @n_Qty                 INT,
           @n_MinHBQty            INT,  
			     @n_Pallet              INT,  --How many PCE in one pallet
			     @n_PALCount            INT,  --How many Pallet putaway in HB 
			     @n_PALSeq              INT,  --Pallet Sequence in the ASN
			     @n_PALQty              INT, 
			     @n_RemainQty           INT,  
			     @n_MZ_B                INT,
			     @n_MZ_S                INT,
           @c_FinalizeFlag        NCHAR(1)
   
   DECLARE 
           @n_RowRefNo            INT,
           @c_LOC                 NVARCHAR(10),  --Inventory table
           @n_AvaQty              INT,           --Inventory table
			     @n_MZAssign_F          INT,           --First time to Assign MZ Big
			     @n_MZAssign_B          INT,           --Assign to MZ Big
			     @n_MZAssign_S          INT,           --Assign to MZ Small
			     @c_CompareLoc_B        NVARCHAR(10),  --Compare Loc-Big
			     @c_CompareLoc_S        NVARCHAR(10),  --Compare Loc-Small
			     @n_MZCount_B           INT,
			     @n_MZCount_S           INT,
			     @c_LocationCategory    NVARCHAR(20),
			     @n_GetRowCount         INT,
			     @n_DiffCount           INT            --Empty Loc Diff
   
   DECLARE  @c_RSO                 NVARCHAR(20),
            @c_RSOSKU              NVARCHAR(20),
			@n_RSOQty              INT,
			@n_RSOAssignQty        INT,
			@n_PUTQty              INT,
            @n_SplitQty            INT

   DECLARE  @c_ReceiptLineNumber   NVARCHAR(5),
            @n_QtyExpected         INT,
			@c_PALSeq              NVARCHAR(18)
       
                                   
   DECLARE  @n_continue            INT,
            @b_success             INT,
            @n_err                 INT,
            @c_errmsg              NVARCHAR(255),
            @n_starttcnt		   INT
            
   SELECT @n_continue = 1, @b_success = 1, @n_err = 0, @n_StartTCnt=@@TRANCOUNT 
   SELECT @c_ID = '', @c_ToLoc = '', @c_FinalizeFlag = 'N'
   SELECT @n_PalSeq = 1

	--BEGIN TRAN	
    --BEGIN TRANSACTION;   
   -- insert into Receipt Header

   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN     	        
     SELECT TOP 1 
            @c_ExternReceiptKey   = ORDERS.ExternOrderkey, 
            @c_WarehouseReference = ORDERS.Orderkey,
            @c_Type               = ORDERS.Type,
            @c_ToFacility         = ORDERS.Consigneekey,             
            @c_ToStorerkey        = ORDERS.Storerkey,
            @c_Storerkey          = ORDERS.Storerkey,
			@c_ReceiptGroup       = ORDERS.OrderGroup,
			@c_Site               = ORDERS.Userdefine01,  --wwang03
            @c_DocType            = 'R'
     FROM  ORDERS WITH (NOLOCK)
     LEFT JOIN  CODELKUP WITH (NOLOCK) ON ORDERS.Type = CODELKUP.Code AND ORDERS.StorerKey = CODELKUP.StorerKey AND CODELKUP.ListName = 'ORDTYP2ASN' 
     WHERE ORDERS.OrderKey = @c_OrderKey        
     
     
     IF NOT EXISTS ( SELECT 1 FROM FACILITY WITH (NOLOCK) WHERE Facility = @c_ToFacility )
     BEGIN
		SET @n_continue = 3
		SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
		SET @n_err = 63490   
	    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Facility: ' + RTRIM(ISNULL(@c_ToFacility,'')) +
                      ' (ispPopulateToASN_NIKECRW)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
     END

	 IF @c_ReceiptGroup = '' OR @c_ReceiptGroup IS NULL
	 BEGIN
		SET @n_continue = 3
		SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
		SET @n_err = 63491   
	    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid ReceiptGroup (ispPopulateToASN_NIKECRW)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
     END

     IF @c_ExternReceiptKey = '' OR @c_ExternReceiptKey IS NULL OR @c_Site = '' OR @c_Site IS NULL
	 BEGIN
	   SET @n_continue = 3
	   SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
	   SET @n_err = 63492   
	   SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+':The Order Not Invalid' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
	 END	 		 	  	
		     
	 IF @n_continue = 1 OR @n_continue = 2
	 BEGIN 				
	    IF Exists(SELECT 1 FROM Receipt WITH(NOLOCK) WHERE Storerkey = @c_StorerKey AND ExternReceiptKey = @c_ExternReceiptkey)
	    BEGIN
		  SET @n_continue = 3
		  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
		  SET @n_err = 63492   
	      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+':Receipt Exists' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
	    END	 
	    ELSE  --Not Exists Open ASN
	    BEGIN
	       -- get new receipt key
	       SELECT @b_success = 0
	       EXECUTE   nspg_getkey
	            'RECEIPT'
	            , 10
	            , @c_NewReceiptKey OUTPUT
	            , @b_success OUTPUT
	            , @n_err OUTPUT
	            , @c_errmsg OUTPUT
	            
	        IF @b_success = 1
	        BEGIN
	           INSERT INTO RECEIPT (ReceiptKey, ExternReceiptkey, Warehousereference, StorerKey, RecType, ReceiptGroup,  Facility, DocType, RoutingTool, Userdefine01)
	           VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_WarehouseReference, @c_ToStorerKey, @c_Type, @c_ReceiptGroup, @c_ToFacility, @c_DocType, 'N', @c_Site)
              
			   SET @n_err = @@Error
               IF @n_err <> 0
               BEGIN
 	             SET @n_continue = 3
	             SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
				 SET @n_err = 63498   
	   		     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error on Table Receipt (ispPopulateToASN_NIKECRW)' + ' ( ' + 
                                   ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
               END
	        END --@b_Success = 1
	        ELSE --@b_Success = 0
	        BEGIN
	           SET @n_continue = 3
	           SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err) 
			   SET @n_err = 63499   
	   		   SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateToASN_NIKECRW)' 
	   			                 + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
			END
	      END --Not exists Open ASN
	    END    -- if continue = 1 or 2


	   IF @n_continue = 1 OR @n_continue = 2
	   BEGIN    
	      
		  DECLARE @t_SKU TABLE (SKU NVARCHAR(20), SKUGroup NVARCHAR(20), ItemClass NVARCHAR(20), QTY INT, MinHBQty INT, Pallet INT, MZ_S INT, MZ_B INT)
		    
	      INSERT INTO @t_SKU
          SELECT ORD.SKU, SKU.SKUGroup, SKU.ItemClass,
		        Sum(QtyPicked+ShippedQty) AS QTY, Min(Cast(Codelkup.Short AS INT)) AS MinHBQty, 
				CONVERT(INT, SKUConfig.Userdefine03) AS Pallet, CONVERT(INT, SKUConfig.Userdefine02) AS MZ_S, CONVERT(INT, SKUConfig.Userdefine01) AS MZ_B
          FROM  OrderDetail AS ORD WITH (NOLOCK)
		  JOIN  SKU WITH (NOLOCK) ON ORD.Storerkey = SKU.StorerKey AND ORD.SKU = SKU.SKU
		  LEFT JOIN CODELKUP WITH (NOLOCK) ON Listname = 'NK-PUTAWAY' AND SKU.SKUGroup = Codelkup.Code
		  LEFT JOIN SKUConfig WITH(NOLOCK) ON SKU.Storerkey = SKUConfig.Storerkey AND SKU.SKU = SKUConfig.SKU AND ConfigType = 'NK-PUTAWAY'
          WHERE OrderKey = @c_OrderKey 
		  GROUP BY ORD.SKU, SKUConfig.Userdefine03, SKU.SKUGroup, SKU.ItemClass, SKUConfig.Userdefine01, SKUConfig.Userdefine02
		  ORDER BY ORD.SKU

		  DECLARE @t_RSO TABLE (RSO NVARCHAR(20), SKU NVARCHAR(20), QTY INT)

          INSERT INTO @t_RSO
		  SELECT Lottable01 AS RSO, SKU, SUM(QtyPicked+ShippedQty) AS QTY
		  FROM OrderDetail AS ORD WITH (NOLOCK)
		  WHERE OrderKey = @c_OrderKey
		  GROUP By ORD.Lottable01, SKU
		  ORDER BY Lottable01, SKU

		  CREATE TABLE #Result
		  ( RowRefNo     INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
			SKU          NVARCHAR(20),
            Loc          NVARCHAR(10),
			ID           NVARCHAR(10),
			PALSeq       INT,
            QtyExpected  INT,
            RSO          NVARCHAR(18),   
			Type         NVARCHAR(10),
			IsAssigned   INT    
           )

		   CREATE TABLE #Inventory
		   ( ROWREFNo     INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
		     SKU          NVARCHAR(20),
			 SKUGroup     NVARCHAR(10),
			 ItemClass    NVARCHAR(10),
		     Loc          NVARCHAR(10),
			 Type         NVARCHAR(10),
			 MaxQty       INT,
			 CurrQty      INT,
			 AvaQty       INT,
			 AssignQty    INT,
			 Status       NVARCHAR(2)
		   )
		    CREATE INDEX #IDX_Inventory_SKULOC ON #Inventory (SKU, Loc)

			CREATE TABLE #EmptyLoc
			( Loc               NVARCHAR(10) PRIMARY KEY,
			  PutawayZone       NVARCHAR(10),
			  LocationCategory  NVARCHAR(10)
			)
            

			--insert Full Mezznine Inventory
		    INSERT INTO #Inventory(SKU, SKUGroup, ItemClass, Loc, Type, MaxQty, CurrQty, AvaQty, AssignQty, Status)
            SELECT SKU, SKUGroup, ItemClass, LOC, LocationCategory, MAX(MaxQty) AS MaxQty, 
			         SUM(CurrQty) AS CurrQty, MAX(MaxQty) - SUM(CurrQty) AS AvaQty, 0 AS AssignQty, '0'
			FROM (
            SELECT SL.SKU, SKUGroup, ItemClass, SL.Loc, LocationCategory, CASE WHEN LOC.LocationCategory = 'MEZZANINEB' THEN SC.Userdefine01 
			                                                                   WHEN LOC.LocationCategory = 'MEZZANINES' THEN SC.Userdefine02 END as MaxQty,
				SL.Qty - SL.QtyPicked AS CurrQty, 0 AS RemainQty, 0 AS AssignQty    
			FROM SKUxLOC AS SL WITH(NOLOCK)
			JOIN SKU WITH(NOLOCK) ON SL.StorerKey = SKU.StorerKey AND SL.SKU = SKU.SKU
			JOIN SKUConfig AS SC WITH(NOLOCK) ON SKU.StorerKey = SC.Storerkey AND SKU.SKU = SC.SKU AND ConfigType = 'NK-PUTAWAY'
			JOIN LOC WITH(NOLOCK) ON SL.Loc = LOC.Loc
			JOIN Codelkup WITH(NOLOCK) ON Codelkup.Listname = 'ALLSORTING' AND Codelkup.Code = @c_Site AND LOC.PickZone = Codelkup.Code2  --wwang03
			WHERE SL.StorerKey = @c_StorerKey AND SL.Qty>0 AND LOC.LocationCategory IN('MEZZANINES','MEZZANINEB')
			UNION ALL
			SELECT LL.SKU, SKUGroup, ItemClass, Lottable03, LocationCategory, 
				   0, LL.Qty - LL.QtyPicked AS CurrQty, 0, 0   
			FROM LOTXLOCXID AS LL WITH(NOLOCK)
			JOIN LOTATTRIBUTE AS LA WITH(NOLOCK) ON LL.StorerKey = LA.StorerKey AND LL.LOT = LA.LOT
			JOIN SKU WITH(NOLOCK) ON LL.StorerKey = SKU.StorerKey AND LL.SKU = SKU.SKU
			JOIN LOC WITH(NOLOCK) ON LA.Lottable03 = LOC.Loc
			JOIN Codelkup WITH(NOLOCK) ON Codelkup.Listname = 'ALLSORTING' AND Codelkup.Code = @c_Site AND LOC.PickZone = Codelkup.Code2  --wwang03
			WHERE LL.StorerKey = @c_StorerKey AND LOC.Facility = @c_ToFacility AND LL.Qty>0 AND LL.ID <> 'HB' AND LA.Lottable03 <> 'CPS'
			UNION ALL
			SELECT RD.SKU, SKUGroup, ItemClass, Lottable03, LocationCategory, 
				   0, RD.QtyExpected AS CurrQty, 0, 0   
			FROM RECEIPTDETAIL AS RD WITH(NOLOCK)
			JOIN RECEIPT AS RH WITH(NOLOCK) ON RD.ReceiptKey = RH.ReceiptKey
			JOIN SKU WITH(NOLOCK) ON RD.StorerKey = SKU.StorerKey AND RD.SKU = SKU.SKU
			JOIN LOC WITH(NOLOCK) ON RD.Lottable03 = LOC.Loc 
			WHERE RD.Storerkey = @c_StorerKey AND RH.Facility = @c_ToFacility AND RH.ReceiptGroup = @c_ReceiptGroup AND RH.Userdefine01 = @c_Site AND FinalizeFlag = 'N' AND RD.ID <> 'HB' ) AS T --wwang03
			GROUP BY SKU, SKUGroup, ItemClass, LOC, LocationCategory
			ORDER BY LocationCategory, Loc

			--Insert Empty Mezznine Loc
			INSERT INTO #EmptyLoc(Loc, PutawayZone, LocationCategory)
			SELECT LOC.Loc, PutawayZone, LocationCategory
			FROM LOC WITH(NOLOCK) LEFT JOIN #Inventory AS INV ON LOC.LOC = INV.LOC
			JOIN Codelkup WITH(NOLOCK) ON Codelkup.Listname = 'ALLSORTING' AND Codelkup.Code = @c_Site AND LOC.PickZone = Codelkup.Code2 --wwang03
			WHERE Facility = @c_ToFacility 
			AND LOC.LocationCategory IN('MEZZANINES','MEZZANINEB')
			AND LOC.PutawayZone <> 'CPSZONE'
			AND INV.Loc IS NULL
			ORDER BY LocationCategory, LOC.Loc

			--SELECT * FROM #Inventory
			--SELECT * FROM #EmptyLoc
			--SELECT * FROM @t_SKU

	      DECLARE Cur_SKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT SKU, SKUGroup, ItemClass, Qty, MinHBQty, Pallet, MZ_S, MZ_B
          FROM @t_SKU SKU
            
          OPEN Cur_SKU
            
          FETCH FROM Cur_SKU INTO @c_SKU, @c_SKUGroup, @c_ItemClass, @n_Qty, @n_MinHBQty, @n_Pallet, @n_MZ_S, @n_MZ_B
            
          WHILE @@FETCH_STATUS = 0 
          BEGIN  
		    SET @n_PALCount = 0
			SET @n_RemainQty = 0
		    --HB Loc
			IF @n_Qty >= @n_MinHBQty
			BEGIN
			  SET @n_PALCount = @n_Qty / @n_Pallet   --Full Pallet
			  SET @n_RemainQty = @n_Qty % @n_pallet

			  IF @n_RemainQty >0 AND @n_RemainQty >= @n_MinHBQty  --Loose Palet
			  BEGIN
			    SET @n_PALCount = @n_PALCount + 1
				SET @n_RemainQty = @n_RemainQty - @n_Pallet
				IF @n_RemainQty < 0
				   SET @n_RemainQty = 0
			  END

			  --SELECT @c_SKU, @n_Qty, @n_PALCount, @n_RemainQty, @n_MinHBQty, @n_Pallet, @n_MZ_S, @n_MZ_B
			  --Insert HB into ReceiptDetail
			  WHILE @n_PALCount > 0
			  BEGIN
			    --Get Pallet ID
				SELECT @b_success = 0
	            EXECUTE   nspg_getkey
	            'PALLETID'
	            , 10
	            , @c_ID      OUTPUT
	            , @b_success OUTPUT
	            , @n_err     OUTPUT
	            , @c_errmsg  OUTPUT
	            
	            IF @b_success = 1
	            BEGIN
				   IF @n_Qty >= @n_Pallet
				      SET @n_PALQty = @n_Pallet
					ELSE
					  SET @n_PALQty = @n_Qty

					SET @n_Qty = @n_Qty - @n_PALQty

				   INSERT INTO #Result(SKU, Loc, ID, PALSeq, QtyExpected, RSO, Type, IsAssigned)
				   Values(@c_SKU, 'HB', @c_ID, @n_PALSeq, @n_PALQty, '', 'HB', 0)

				   SET @n_PALCount = @n_PALCount - 1
				   SET @n_PALSeq   = @n_PALSeq  + 1

				END  --@b_success = 1
				ELSE
				BEGIN
				  SET @n_continue = 3
	              SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err) 
				  SET @n_err = 63500   
	   			  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Generate Pallet ID Failed! (ispPopulateToASN_NIKECRW)' 
	   			                 + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
				END --@b_Success = 0

			  END --While End
			    
			END  --HB Loc
			ELSE
			  SET @n_RemainQty = @n_Qty

            IF @n_RemainQty >0
			BEGIN
		      --Start Mezzanine
			  --SELECT @n_RemainQty

			  IF Exists(SELECT 1 FROM #Inventory WHERE SKU = @c_SKU AND AvaQty >0)
			  BEGIN

			    --SELECT * from #Inventory WHERE SKU = @c_SKU and AvaQty>0
		    	WHILE 1=1
			    BEGIN

			      SET ROWCOUNT 1
              
			      SELECT @n_RowRefNo =  RowRefNo,
				         @c_Loc      =  LOC,
				         @n_AvaQty   =  AvaQty,
						 @c_LocationCategory = Type
				  FROM #Inventory
				  WHERE SKU = @c_SKU AND AvaQty > 0 AND Status = '0'
				  ORDER BY Type, LOC

				  IF @@Rowcount = 0
				  BEGIN
				      SET ROWCOUNT 0 
				      BREAK
                  END

				  IF @n_AvaQty < @n_RemainQty
			      BEGIN
				    SET @n_RemainQty = @n_RemainQty - @n_AvaQty

				    INSERT INTO #Result(SKU, Loc, ID, PALSeq, QtyExpected, RSO, Type, IsAssigned)
				    Values(@c_SKU, @c_LOC, '', '', @n_AvaQty, '', 'MZ_E_1', 0)

				    Update #Inventory
				    SET   Status = '9'
				    WHERE RowRefNo = @n_RowRefNo

				  END
				  ELSE
				  BEGIN
				    INSERT INTO #Result(SKU, Loc, ID, PALSeq, QtyExpected, RSO, Type, IsAssigned)
				    Values(@c_SKU, @c_LOC, '', 0, @n_RemainQty, '', 'MZ_E_2', 0)

				    SET @n_RemainQty = 0

					SET ROWCOUNT 0 

				    BREAK
				  END

			   	 
				    
			     END  --WHILE 1=1
			  END  --Exists #Inventory 
			
			  IF @n_RemainQty >0  --Existsing LOC full, @n_RemainQty >0
			  BEGIN
			     --SELECT @n_RemainQty

				 SELECT @c_CompareLoc_B = MAX(CASE WHEN Type = 'MEZZANINEB' THEN LOC ELSE '' END),
				        @c_CompareLoc_S = MAX(CASE WHEN Type = 'MEZZANINES' THEN LOC ELSE '' END)
				 FROM #Inventory
				 WHERE SKU = @c_SKU

				 IF @c_CompareLoc_B = '' OR @c_CompareLoc_B IS NULL
				    SELECT @c_CompareLoc_B = MAX(LOC)
					FROM #Inventory
					WHERE ItemClass = @c_ItemClass AND Type = 'MEZZANINEB'
				 
				 IF @c_CompareLoc_S = '' OR @c_CompareLoc_S IS NULL
				    SELECT @c_CompareLoc_S = MAX(LOC)
					FROM #Inventory
					WHERE ItemClass = @c_ItemClass AND Type = 'MEZZANINES'

			     IF @c_CompareLoc_B IS NULL
				    SET @c_CompareLoc_B = ''
				 
				 IF @c_CompareLoc_S IS NULL
				    SET @c_CompareLoc_S = ''


				SET @n_MZAssign_F = 0  --wwang02
                 
				 --select * from #Inventory(nolock)
				 --Select @c_CompareLoc_B, @c_CompareLoc_S, @c_ItemClass, @c_SKU
				 --Start processing
				 --Assign to Big Slot first
				 IF @n_MZ_B > 0
				 BEGIN
				   SET @n_MZAssign_F = ((@n_RemainQty / @n_MZ_B) -1) * @n_MZ_B

				   IF @n_MZAssign_F < 0      --wwang01
				      SET @n_MZAssign_F = 0  --wwang01
				   ELSE IF @n_MZAssign_F = 0    --wwang01
				      SET @n_MZAssign_F = @n_MZ_B  --wwang01

				   IF @n_MZAssign_F > 0 
				   BEGIN
				      SET @n_GetRowCount = 0
					  
					  SET @n_GetRowCount = @n_MZAssign_F / @n_MZ_B


				      SET ROWCOUNT @n_GetRowCount

					  INSERT INTO #Result(SKU, Loc, ID, PALSeq, QtyExpected, RSO, Type, IsAssigned)
					  SELECT @c_SKU, Loc, '', 0, @n_MZ_B, '', 'MZ_N_1', 0
					  FROM #EmptyLoc
					  WHERE PutawayZone = @c_SKUGroup AND LocationCategory = 'MEZZANINEB' AND LOC > @c_CompareLoc_B
					  ORDER BY LOC

					  

					  SET @n_DiffCount = @n_GetRowCount - @@ROWCOUNT

					    IF @n_DiffCount > 0
					    BEGIN
						  SET ROWCOUNT 0

						   DELETE #EmptyLoc
				           FROM #Result
				           WHERE #Result.Type = 'MZ_N_1' AND #EmptyLoc.Loc = #Result.Loc

						  SET ROWCOUNT @n_DiffCount
						  
						  INSERT INTO #Result(SKU, Loc, ID, PALSeq, QtyExpected, RSO, Type, IsAssigned)
					      SELECT @c_SKU, Loc, '', 0, @n_MZ_B, '', 'MZ_N_2', 0
					      FROM #EmptyLoc
					      WHERE PutawayZone = @c_SKUGroup AND LocationCategory = 'MEZZANINEB' AND LOC < @c_CompareLoc_B
					      ORDER BY LOC DESC

						  SET @n_DiffCount = @n_DiffCount - @@ROWCOUNT

						  /* wwang04
					      WHILE @n_DiffCount  > 0
					      BEGIN
					        INSERT INTO #Result(SKU, Loc, ID, PALSeq, QtyExpected, RSO, Type, IsAssigned)
					        VALUES( @c_SKU, 'NOLOC', '', 0, @n_MZ_B, '', 'MZ_N_3', 0)

					        SET @n_DiffCount = @n_DiffCount - 1
					      END
						 */
						 SET @n_MZAssign_F = @n_MZAssign_F - @n_DiffCount * @n_MZ_B  --wwang04
					    END

					    SET ROWCOUNT 0
 
					    DELETE #EmptyLoc
				    	FROM #Result
				     	WHERE #Result.Type  IN ('MZ_N_1', 'MZ_N_2') AND #EmptyLoc.Loc = #Result.Loc

						--SELECT * FROM #EmptyLoc
				   END
				 END --n_MZ_B>0
                 --Assign Remaining
				 --SELECT @n_RemainQty, @n_MZAssign_F, @n_MZ_B, @n_MZ_S
				 SELECT @n_MZCount_B = COUNT(LOC) FROM #EMPTYLOC WHERE PutawayZone = @c_SKUGroup AND LocationCategory = 'MEZZANINEB'  --wwang04
				 SELECT @n_MZCount_S = COUNT(LOC) FROM #EMPTYLOC WHERE PutawayZone = @c_SKUGroup AND LocationCategory = 'MEZZANINES'  --wwang04

				 IF (@n_MZ_B = 0 AND @n_MZ_S = 0) OR (@n_MZCount_B= 0 AND @n_MZCount_S = 0) OR (@n_MZ_B = 0 AND @n_MZCount_S = 0) OR (@n_MZ_S = 0 AND @n_MZCount_B = 0)
				 BEGIN
				  SET @n_continue = 3
	              SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err) 
				  SET @n_err = 63501  
	   			  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No Invalid LOC! (ispPopulateToASN_NIKECRW)' 
	   			                 + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
				 END
	             ELSE IF ((@n_RemainQty - @n_MZAssign_F) > 0 AND @n_MZ_B = 0) OR ((@n_RemainQty - @n_MZAssign_F) > 0 AND @n_MZCount_B = 0) OR ((@n_RemainQty - @n_MZAssign_F) > 0 AND (@n_MZ_S > 0) AND (@n_MZCount_S > 0) AND CEILING(CAST((@n_RemainQty - @n_MZAssign_F) AS FLOAT) / CAST(@n_MZ_B AS FLOAT)) = CEILING(CAST((@n_RemainQty - @n_MZAssign_F) AS FLOAT) / CAST(@n_MZ_S AS FLOAT))) --wwang02  wwang04
				 BEGIN
				    select @n_MZ_S, @n_MZCount_S
				    SET @n_GetRowCount = 0

					SET @n_GetRowCount = CEILING(CAST((@n_RemainQty - @n_MZAssign_F) AS FLOAT) / CAST(@n_MZ_S AS FLOAT))

					IF @n_GetRowCount =0 AND @n_MZ_S > 0      --wwang01  wwang02
					  SET @n_GetRowCount = 1                  --wwang01


			     	WHILE @n_GetRowCount > 0
				    BEGIN
					  SET @n_MZ_S = CASE WHEN @n_MZ_S > (@n_RemainQty - @n_MZAssign_F) THEN (@n_RemainQty - @n_MZAssign_F) ELSE @n_MZ_S END


					  SET ROWCOUNT 1

					  SET @c_Loc = ''

					  SELECT @c_Loc = Loc 
				      FROM #EmptyLoc 
					  WHERE PutawayZone = @c_SKUGroup AND LocationCategory = 'MEZZANINES' AND LOC > @c_CompareLoc_S
					  ORDER BY LOC

					  IF @c_Loc = ''
					  BEGIN
					     SELECT @c_Loc = Loc 
				         FROM #EmptyLoc 
					     WHERE PutawayZone = @c_SKUGroup AND LocationCategory = 'MEZZANINES' AND LOC < @c_CompareLoc_S
					     ORDER BY LOC DESC
					  END

					  /*IF @c_Loc = ''
					     SET @c_Loc = 'NOLOC'*/

		
		     
					  INSERT INTO #Result(SKU, Loc, ID, PALSeq, QtyExpected, RSO, Type, IsAssigned)
					  VALUES(@c_SKU, @c_Loc, '', 0, @n_MZ_S, '', 'MZ_N_4', 0)

					  SET ROWCOUNT 0

					  SET @n_MZAssign_F = @n_MZAssign_F + @n_MZ_S


					  SET @n_GetRowCount = @n_GetRowCount - 1

					  DELETE #EmptyLoc
					  FROM #Result
					  WHERE #Result.Type = 'MZ_N_4' AND #EmptyLoc.Loc = #Result.Loc
				   END
                  
				 END
				 
				 ELSE IF ((@n_RemainQty - @n_MZAssign_F) > 0 AND @n_MZ_S = 0) OR ((@n_RemainQty - @n_MZAssign_F) > 0 AND @n_MZCount_S =0) OR ((@n_RemainQty - @n_MZAssign_F) > 0 AND (@n_MZ_B > 0) AND (@n_MZCount_B > 0) AND (@n_RemainQty - @n_MZAssign_F) > 0 AND CEILING(CAST((@n_RemainQty - @n_MZAssign_F) AS FLOAT) / CAST(@n_MZ_B AS FLOAT)) < CEILING(CAST((@n_RemainQty - @n_MZAssign_F) AS FLOAT) / CAST(@n_MZ_S AS FLOAT)))
				 BEGIN
				   
				   SET @c_Loc = ''
				   
				   SET @n_MZ_B = CASE WHEN @n_MZ_B > (@n_RemainQty - @n_MZAssign_F) THEN (@n_RemainQty - @n_MZAssign_F) ELSE @n_MZ_B END

				   SET ROWCOUNT 1
				   
				   SELECT @c_Loc = Loc 
				   FROM #EmptyLoc 
				   WHERE PutawayZone = @c_SKUGroup AND LocationCategory = 'MEZZANINEB' AND LOC > @c_CompareLoc_B
				   ORDER BY LOC

				   IF @c_Loc = ''
				   BEGIN
				     SELECT @c_Loc = Loc 
				     FROM #EmptyLoc 
				     WHERE PutawayZone = @c_SKUGroup AND LocationCategory = 'MEZZANINEB' AND LOC < @c_CompareLoc_B
				     ORDER BY LOC DESC
				   END

				    IF @c_Loc = ''
					    SET @c_Loc = 'NOLOC' 


				     INSERT INTO #Result(SKU, Loc, ID, PALSeq, QtyExpected, RSO, Type, IsAssigned)
				     VALUES(@c_SKU, @c_Loc, '', 0, @n_MZ_B, '', 'MZ_N_5', 0)

				     SET ROWCOUNT 0

				     DELETE #EmptyLoc WHERE LOC = @c_Loc

				     SET ROWCOUNT 1


				   SELECT @n_MZCount_B = COUNT(LOC) FROM #EmptyLOC WHERE PutawayZone = @c_SKUGroup AND LocationCategory = 'MEZZANINEB'
				   SELECT @n_MZCount_S = COUNT(LOC) FROM #EMPTYLOC WHERE PutawayZone = @c_SKUGroup AND LocationCategory = 'MEZZANINES'

                   IF ((@n_MZCount_B) = 0) OR ((@n_RemainQty - @n_MZAssign_F - @n_MZ_B) > 0 AND (@n_RemainQty - @n_MZAssign_F - @n_MZ_B) <= @n_MZ_S)
				   BEGIN

				     SET @c_Loc = ''
				     
                     SELECT @c_Loc = Loc 
				     FROM #EmptyLoc 
				     WHERE PutawayZone = @c_SKUGroup AND LocationCategory = 'MEZZANINES' AND LOC > @c_CompareLoc_S
				     ORDER BY LOC

					 IF @c_Loc = ''
					 BEGIN
					   SELECT @c_Loc = Loc 
				       FROM #EmptyLoc 
				       WHERE PutawayZone = @c_SKUGroup AND LocationCategory = 'MEZZANINES' AND LOC < @c_CompareLoc_S
				       ORDER BY LOC DESC
					 END

					 IF @c_Loc = ''
					    SET @c_Loc = 'NOLOC' 

                    
					   INSERT INTO #Result(SKU, Loc, ID, PALSeq, QtyExpected, RSO, Type, IsAssigned)
				       VALUES(@c_SKU, @c_Loc, '', 0, @n_RemainQty - @n_MZAssign_F - @n_MZ_B, '', 'MZ_N_6', 0)

				   END
				   ELSE IF (@n_RemainQty - @n_MZAssign_F - @n_MZ_B) > 0 AND (@n_RemainQty - @n_MZAssign_F - @n_MZ_B) > @n_MZ_S
				   BEGIN

				     SET @c_Loc = ''

				     SELECT @c_Loc = Loc 
				     FROM #EmptyLoc
				     WHERE PutawayZone = @c_SKUGroup AND LocationCategory = 'MEZZANINEB' AND LOC > @c_CompareLoc_B
				     ORDER BY LOC

					 IF @c_Loc = ''
					 BEGIN
					   SELECT @c_Loc = Loc 
				       FROM #EmptyLoc
				       WHERE PutawayZone = @c_SKUGroup AND LocationCategory = 'MEZZANINEB' AND LOC < @c_CompareLoc_B
				       ORDER BY LOC DESC
					 END

					 IF @c_Loc = ''
					    SET @c_Loc = 'NOLOC' 
               
					   INSERT INTO #Result(SKU, Loc, ID, PALSeq, QtyExpected, RSO, Type, IsAssigned)
				       VALUES(@c_SKU, @c_Loc, '', 0, @n_RemainQty - @n_MZAssign_F - @n_MZ_B, '', 'MZ_N_7', 0)
				   END

				   SET ROWCOUNT 0

				   DELETE #EmptyLoc WHERE LOC = @c_Loc

				 END
				
			  END  --@RemianQty>0
			   
			END --@RemianQty>0
			

		    GET_NEXT_SKU:
          FETCH FROM Cur_SKU INTO @c_SKU, @c_SKUGroup, @c_ItemClass,  @n_Qty, @n_MinHBQty, @n_Pallet, @n_MZ_S, @n_MZ_B
          END
          CLOSE Cur_SKU
          DEALLOCATE Cur_SKU
		END

     --select * from #Result

	 IF @n_continue = 1 OR @n_continue = 2
	 BEGIN 
	
	   --split line by RSO#.
	    DECLARE Cur_RSO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT RSO, SKU, Qty
        FROM @t_RSO RSO
            
        OPEN Cur_RSO
            
        FETCH FROM Cur_RSO INTO @c_RSO, @c_RSOSKU, @n_RSOQty
              
        WHILE @@FETCH_STATUS = 0 
        BEGIN  
		  
		  SET @n_RSOAssignQty = @n_RSOQty

	      WHILE @n_RSOAssignQty > 0
		  BEGIN


		    SET RowCount 1

			SET @n_PUTQty = 0

		    SELECT @n_RowRefNo = RowRefNo, @n_PUTQty = QtyExpected
		    FROM #Result
		    WHERE SKU = @c_RSOSKU AND IsAssigned = 0
		    ORDER BY RowRefNo


		      IF @n_RSOAssignQty >= @n_PUTQty
		      BEGIN
			    UPDATE #Result
			    SET RSO = @c_RSO, 
				    IsAssigned = 1
			    WHERE RowRefNo = @n_RowRefNo

			    SET @n_RSOAssignQty = @n_RSOAssignQty - @n_PUTQty

				IF @n_PUTQty = 0
				BEGIN
				  SET @n_RSOAssignQty = 0
				END

		      END
		      ELSE
		      BEGIN
			    SET @n_SplitQty = @n_PUTQty - @n_RSOAssignQty

			    UPDATE #Result
			    SET RSO = @c_RSO,
				    QtyExpected = @n_RSOAssignQty, 
					IsAssigned = 1
			    WHERE RowRefNo = @n_RowRefNo

			    INSERT INTO #Result(SKU, Loc, ID, PALSeq, QtyExpected, RSO, Type, IsAssigned)
			    SELECT SKU, Loc, ID, PALSeq, @n_PUTQty - @n_RSOAssignQty, '',Type, 0
			    FROM #Result
			    WHERE RowRefNo = @n_RowRefNo

			    SET @n_RSOAssignQty = 0
		      END

	         SET RowCount 0
		   END  --While 

	    GET_NEXT_RSO:
        FETCH FROM Cur_RSO INTO @c_RSO, @c_RSOSKU, @n_RSOQty
        END
        CLOSE Cur_RSO
        DEALLOCATE Cur_RSO

	
	    SELECT * from #Result
     
	  
	  --Insert into ReceiptDetail
	  DECLARE Cur_Result CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowRefNo, SKU, Loc, ID, PALSeq, QtyExpected, RSO
      FROM #Result
      OPEN Cur_Result
            
      FETCH FROM Cur_Result INTO @n_RowRefNo, @c_SKU, @c_Loc, @c_ID, @n_PALSeq, @n_QtyExpected, @c_RSO
      WHILE @@FETCH_STATUS = 0 
      BEGIN  

	    SET @c_ReceiptLineNumber = RIGHT( '0000' + RTRIM(CAST(@n_RowRefNo AS NVARCHAR(5))), 5)
		SET @c_PALSeq = CAST(@n_PALSeq AS NVARCHAR(5))
		SELECT @c_PackKey = SKU.Packkey, @c_UOM = PackUOM3
		FROM SKU INNER JOIN PACK ON SKU.Packkey = PACK.Packkey
		WHERE Storerkey = @c_StorerKey AND SKU = @c_SKU

	    INSERT INTO RECEIPTDETAIL(ReceiptKey, ReceiptLineNumber, ExternReceiptKey, ExternLineNo, 
	                            Storerkey,  SKU, QtyExpected, QtyReceived, UOM, PackKey, ToLoc,
								Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
								BeforeReceivedQty, FinalizeFlag, ToID, Userdefine05)
	    VALUES(@c_NewReceiptKey, @c_ReceiptLineNumber, @c_ExternReceiptKey, @c_ReceiptLineNumber, 
	          @c_StorerKey, @c_SKU, @n_QtyExpected, 0, @c_UOM, @c_Packkey, @c_ToLoc, @c_RSO, '01000',  --wwang03
			  @c_Loc, '','','0','N',@c_ID, @n_PALSeq)

       FETCH FROM Cur_Result INTO @n_RowRefNo, @c_SKU, @c_Loc, @c_ID, @n_PALSeq, @n_QtyExpected, @c_RSO
	   END
	   CLOSE Cur_Result
       DEALLOCATE Cur_Result

	 END
	 
     IF (@n_continue = 1 OR @n_continue = 2) AND @c_FinalizeFlag = 'Y'
     BEGIN
        UPDATE RECEIPT WITH (ROWLOCK) 
        SET ASNStatus = '9',  
            Status    = '9'  
        WHERE ReceiptKey = @c_NewReceiptKey      

	   	  SET @n_err = @@Error
            
        IF @n_err <> 0
        BEGIN
 	      		SET @n_continue = 3
	          SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
				    SET @n_err = 63492   
	   		    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error on Table Receipt (ispPopulateToASN_NIKECRW)' + ' ( ' + 
                       ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        END              
     END
	
		 QUIT_SP:

		 IF @n_continue = 3  -- Error Occured - Process And Return
	   BEGIN
	      SELECT @b_success = 0
	   
	      --IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt
	      --BEGIN
	         --ROLLBACK TRAN
	      --END
	      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateToASN_NIKECRW'
	      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
	      RETURN
	   END
	   ELSE
	   BEGIN
	      SELECT @b_success = 1
	      -- WHILE @@TRANCOUNT >= @n_starttcnt
	      -- BEGIN
	      --    COMMIT TRAN
	      -- END
	      RETURN
	   END        
	END -- if continue = 1 or 2 001
END

GO