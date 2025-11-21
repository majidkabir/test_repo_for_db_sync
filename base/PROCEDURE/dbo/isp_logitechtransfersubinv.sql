SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_LogitechTransferSubInv                            */
/* Creation Date: 20-APR-2021                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-16777 - SG Logitech - Auto create transfer to transfer     */
/*          sub inventory                                                  */
/*                                                                         */
/* Called By: SQL Backend Job Every Sunday                                 */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 04-May-2021  NJOW01  1.0   WMS-16777 - Set BTRXTEM1 as transfer to      */
/*                            location                                     */
/***************************************************************************/  
CREATE PROC [dbo].[isp_LogitechTransferSubInv]    
AS  
BEGIN  	
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @b_Success             INT,
           @n_Err                 INT,
           @c_ErrMsg              NVARCHAR(255),
           @n_Continue            INT,
           @n_StartTranCount      INT
                                  
   DECLARE @c_Storerkey           NVARCHAR(15),
           @c_Sku                 NVARCHAR(20),
           @c_Transferkey         NVARCHAR(10),
           @c_Lot                 NVARCHAR(10),
           @C_Loc                 NVARCHAR(10),
           @c_ID                  NVARCHAR(18),
           @n_BCH_QtyToReplen     INT,
           @n_BCH_QtyAvailable    INT,
           @n_BCH_MaxQty_RSP      INT,
           @n_Casecnt             INT,
           @n_LLIQtyAvailable     INT, 
           @c_Facility            NVARCHAR(5),
           @c_SubInv              NVARCHAR(30), 
           @n_SubInv_RsvQty_CORQ  INT,
           @n_SuvInv_QtyAvailable INT,
           @n_SuvInv_QtyToTake    INT,
           @n_QtyTransfer         INT,
           @c_Lottable08          NVARCHAR(30),
           @c_Remark              NVARCHAR(200),
           @c_ToLoc               NVARCHAR(10),
           @n_SubInv_Qty          INT
       
   SELECT @b_Success=1, @n_Err=0, @c_ErrMsg='', @n_Continue = 1, @n_StartTranCount=@@TRANCOUNT

   --IF @@TRANCOUNT = 0
   --   BEGIN TRAN
   
   IF NOT EXISTS(SELECT 1 FROM LOC (NOLOCK) WHERE LOC = 'BTRXTEM1')
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63200
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': To Loc BTRXTEM1 is not exist in loc table. (isp_LogitechTransferSubInv)' + ' ( '
                     + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   	  
      GOTO QUIT_SP               
   END
   
   
   CREATE TABLE #TMP_LOGIORQ (Rowid INT IDENTITY(1,1), Code2 NVARCHAR(30))
   INSERT INTO #TMP_LOGIORQ (Code2) VALUES ('AP1BFG')
   INSERT INTO #TMP_LOGIORQ (Code2) VALUES ('AP1BCV')
   INSERT INTO #TMP_LOGIORQ (Code2) VALUES ('AP1BCP')
   INSERT INTO #TMP_LOGIORQ (Code2) VALUES ('AP1BRP')
      	   
   IF @n_continue IN(1,2)
   BEGIN
   	  DECLARE CUR_BCHSTOCK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT CL.Storerkey, CL.Code AS Sku, ISNULL(INV.QtyAvailable,0) AS BCH_QtyAvailable, 
                CASE WHEN ISNUMERIC(CL.UDF01) = 1 THEN CAST(CL.UDF01 AS INT) ELSE 0 END AS BCH_MaxQty_RSP,
                PACK.Casecnt
         FROM CODELKUP CL (NOLOCK)
         JOIN SKU (NOLOCK) ON CL.Storerkey = SKU.Storerkey AND CL.Code = SKU.Sku
         JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
         OUTER APPLY (SELECT SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS QtyAvailable
                      FROM LOTXLOCXID LLI (NOLOCK)
                      JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
                      WHERE LLI.Storerkey = CL.Storerkey 
                      AND LLI.Sku = CL.Code
                      AND LA.Lottable08 = CL.Code2) AS INV                    
         WHERE CL.Listname = 'LOGIRSP'
         AND CL.Code2 = 'AP1BCH' 
         AND ISNULL(INV.QtyAvailable,0) < CASE WHEN ISNUMERIC(CL.UDF01) = 1 THEN CAST(CL.UDF01 AS INT) ELSE 0 END

     OPEN CUR_BCHSTOCK  
      
     FETCH NEXT FROM CUR_BCHSTOCK INTO @c_Storerkey, @c_Sku, @n_BCH_QtyAvailable, @n_BCH_MaxQty_RSP, @n_Casecnt
      
     WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
     BEGIN
     	  SET @n_BCH_QtyToReplen = @n_BCH_MaxQty_RSP - (FLOOR(@n_BCH_QtyAvailable / @n_Casecnt) * @n_Casecnt)        
     	  SET @n_BCH_QtyToReplen = FLOOR(@n_BCH_QtyToReplen / @n_Casecnt) * @n_Casecnt
     	  
     	  IF @n_BCH_QtyToReplen = 0
     	     GOTO NEXT_SKU
     	  
     	  DECLARE CUR_SUBINV CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
     	     SELECT TORQ.Code2, CASE WHEN CL.Code2 IS NULL THEN 
                    	             0
                    	        ELSE    
                    	             CASE WHEN ISNUMERIC(CL.UDF01) = 1 THEN CAST(CL.UDF01 AS INT) ELSE 0 END
                    	        END
     	     FROM #TMP_LOGIORQ TORQ
     	     LEFT JOIN CODELKUP CL (NOLOCK) ON TORQ.Code2 = CL.Code2 AND CL.ListName = 'LOGIORQ'
     	                                    AND CL.Storerkey = @c_Storerkey AND CL.Code = @c_Sku  
     	     ORDER BY TORQ.RowId

        OPEN CUR_SUBINV  
         
        FETCH NEXT FROM CUR_SUBINV INTO @c_SubInv, @n_SubInv_RsvQty_CORQ
         
        WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2) AND @n_BCH_QtyToReplen > 0 
        BEGIN        	 
        	 SET @n_SuvInv_QtyAvailable = 0
        	 SET @n_SubInv_Qty = 0
     	     SELECT @n_SuvInv_QtyAvailable = SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked),
     	            @n_SubInv_Qty = SUM(LLI.Qty) --NJOW01
     	     FROM LOTXLOCXID LLI (NOLOCK)
     	     JOIN ID (NOLOCK) ON LLI.Id = ID.Id
     	     JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
     	     JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
     	     JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.Lot = LA.Lot
     	     WHERE ID.Status = 'OK'
     	     AND LOC.LocationFlag = 'NONE'
     	     AND LOC.Status = 'OK'
     	     AND LOT.Status = 'OK'
     	     AND LLI.Storerkey = @c_Storerkey
     	     AND LLI.Sku = @c_Sku     	   
     	     AND LA.Lottable08 = @c_SubInv
     	     
     	     --SET @n_SuvInv_QtyToTake = @n_SuvInv_QtyAvailable - @n_SubInv_RsvQty_CORQ
     	     SET @n_SuvInv_QtyToTake = @n_SubInv_Qty - @n_SubInv_RsvQty_CORQ  --NJOW01
        	
        	 DECLARE CUR_SUBINV_LLI CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
     	        SELECT LLI.Lot, LLI.Loc, LLI.Id, (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS QtyAvailable,
     	               LOC.Facility, LA.Lottable08
     	        FROM LOTXLOCXID LLI (NOLOCK)
     	        JOIN ID (NOLOCK) ON LLI.Id = ID.Id
     	        JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
     	        JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
     	        JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.Lot = LA.Lot
     	        WHERE ID.Status = 'OK'
     	        AND LOC.LocationFlag = 'NONE'
     	        AND LOC.Status = 'OK'
     	        AND LOT.Status = 'OK'
     	        AND LLI.Storerkey = @c_Storerkey
     	        AND LLI.Sku = @c_Sku     	   
     	        AND LA.Lottable08 = @c_SubInv     	       
     	        AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked > @n_Casecnt
     	        ORDER BY LA.Lottable05, LOC.LogicalLocation, LOC.Loc

           OPEN CUR_SUBINV_LLI  
         
           FETCH NEXT FROM CUR_SUBINV_LLI INTO @c_Lot, @c_Loc, @c_Id, @n_LLIQtyAvailable, @c_Facility, @c_Lottable08
         
           WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2) AND @n_BCH_QtyToReplen > 0 AND @n_SuvInv_QtyToTake > 0
           BEGIN       	     	           	  
           	  IF @n_LLIQtyAvailable > @n_SuvInv_QtyToTake 
           	     SET @n_LLIQtyAvailable = @n_SuvInv_QtyToTake
           	  
           	  IF @n_LLIQtyAvailable > @n_BCH_QtyToReplen
           	     SET @n_QtyTransfer = @n_BCH_QtyToReplen  
           	  ELSE
           	     SET @n_QtyTransfer = @n_LLIQtyAvailable
           	     
           	  SET @n_QtyTransfer = FLOOR(@n_QtyTransfer / @n_Casecnt) * @n_Casecnt
           	  
           	  SET @c_ToLoc = 'BTRXTEM1'
           	  
           	  IF @n_QtyTransfer > 0
           	  BEGIN
           	  	 SELECT @c_Remark = 'CHA' + REPLACE(CONVERT(NVARCHAR,GETDATE(),5),'-','') 
           	  	 
      	         SET @b_Success = 0
      	         EXEC ispCreateTransfer
      	            @c_Transferkey = @c_Transferkey OUTPUT,
      	            @c_FromFacility = @c_Facility,
      	            @c_FromLot = @c_Lot,
                    @c_FromLoc = @c_Loc,
                    @c_FromID = @c_ID,
                    @n_FromQty = @n_QtyTransfer,      	           
                    @c_ToLoc = @c_ToLoc,
                    @c_ToLottable08 = 'AP1BCH',
                    @c_ToLottable09 = @c_Lottable08,
      	            @c_CopyLottable = 'Y',
      	            @c_Finalize = 'N',
      	            @c_Type = 'XA',
      	            @c_ReasonCode = 'CHLOT',
      	            @c_Remarks = @c_Remark,    
      	            @b_Success = @b_Success OUTPUT,
      	            @n_Err = @n_Err OUTPUT,
      	            @c_ErrMsg = @c_ErrMsg OUTPUT
                 
   	             IF  @b_Success <> 1
                 BEGIN
                    SELECT @n_continue = 3
   	                SELECT @c_errmsg = RTRIM(@c_Errmsg) +  ' (isp_LogitechTransferSubInv)'
                 END
                 
                 SET @n_BCH_QtyToReplen = @n_BCH_QtyToReplen - @n_QtyTransfer
                 SET @n_SuvInv_QtyToTake = @n_SuvInv_QtyToTake - @n_QtyTransfer
              END
               	          	          	           	         
              FETCH NEXT FROM CUR_SUBINV_LLI INTO @c_Lot, @c_Loc, @c_Id, @n_LLIQtyAvailable, @c_Facility, @c_Lottable08
           END	      	 
           CLOSE CUR_SUBINV_LLI
           DEALLOCATE CUR_SUBINV_LLI               	            
        	  
           FETCH NEXT FROM CUR_SUBINV INTO @c_SubInv, @n_SubInv_RsvQty_CORQ
        END
        CLOSE CUR_SUBINV
        DEALLOCATE CUR_SUBINV
        
        NEXT_SKU:
     	       	  
        FETCH NEXT FROM CUR_BCHSTOCK INTO @c_Storerkey, @c_Sku, @n_BCH_QtyAvailable, @n_BCH_MaxQty_RSP, @n_Casecnt
     END
     CLOSE CUR_BCHSTOCK
     DEALLOCATE CUR_BCHSTOCK    	      	       	       
   END
   
   IF @n_continue IN(1,2) AND ISNULL(@c_Transferkey,'') <> ''
   BEGIN
      EXEC ispFinalizeTransfer @c_Transferkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
      
      IF @b_Success <> 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63210
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Transfer# ' + RTRIM(@c_Transferkey) + ' Failed! (isp_LogitechTransferSubInv)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END   	
   END
      	            
   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_LogitechTransferSubInv'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012          
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN
   END 
END

GO