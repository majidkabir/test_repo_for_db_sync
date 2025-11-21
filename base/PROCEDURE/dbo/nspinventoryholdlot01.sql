SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: nspInventoryHoldLot01                              */  
/* Creation Date: 27-Feb-2012                                           */  
/* Copyright: IDS                                                       */  
/* Written by: KHLim                                                    */  
/*                                                                      */  
/* Purpose: SOS#237307 - MARS : Automatic Inventory HOLD                */  
/*                                                                      */  
/* Called By: BEJ - Auto Create InventoryHold                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/*  6-Mar-2012  KHLim01       include Lottable01 in 'S' & 'R'           */
/*  2-Feb-2017  TLTING        Performance tune and fix hardcode storer  */
/************************************************************************/  
  
  
CREATE PROC [dbo].[nspInventoryHoldLot01]  
            @c_Storerkey NVARCHAR(15)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE  @n_continue   int  
           ,@n_starttcnt  int -- bring forward tran count  
           ,@b_debug      int  
   
   DECLARE  @c_lotitf     NVARCHAR(1)  
           ,@c_Flag       NVARCHAR(1)  
           ,@c_InvHoldKey NVARCHAR(10)  
           ,@c_StreamCode NVARCHAR(10)  
           ,@n_IDCnt      int  
           ,@n_LocCnt     int  

   DECLARE @b_Success int,  
         @n_err      INT,  
         @c_errmsg   NVARCHAR(225),  
         @c_Status   NVARCHAR(1) 
   DECLARE @lot      NVARCHAR(10), 
         @chold      NVARCHAR(10)  

              
   SELECT @n_continue = 1, @b_debug = 0  
   SELECT @n_starttcnt = @@TRANCOUNT  

   CREATE TABLE #LotByBatch  
    ( LOT NVARCHAR(10),  
      InventoryHoldKey NVARCHAR(10),  
      HOLD NVARCHAR(10) )  

   SET @c_Storerkey = ISNULL(RTRIM(@c_Storerkey), '')

   IF @c_Storerkey  = ''
   BEGIN 
      SET @n_continue = 3
   END

   INSERT INTO #LotByBatch
   SELECT DISTINCT LOTATTRIBUTE.LOT, '' InventoryHoldKey, '0' HOLD  
   FROM  LOTATTRIBUTE WITH (NOLOCK)  
   JOIN SKU WITH (NOLOCK) ON (LOTATTRIBUTE.StorerKey = SKU.StorerKey AND LOTATTRIBUTE.SKU = SKU.SKU )  
   WHERE NOT EXISTS (SELECT LOT FROM InventoryHold (NOLOCK) 
                  WHERE Inventoryhold.Lot = LOTATTRIBUTE.Lot )  --AND InventoryHold.HOLD = '1'
    AND  LOTATTRIBUTE.Storerkey = @c_Storerkey  
    AND  LOTATTRIBUTE.Lottable01 IN ('X','S','R')  -- KHLim01
    AND  EXISTS ( SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE LOTATTRIBUTE.lot = LOTxLOCxID.lot AND     
                                     LOTxLOCxID.qty > 0 ) 
        
   IF @b_debug = 1   
   BEGIN  
      SELECT * FROM #LotByBatch  
   END  
   IF NOT EXISTS( SELECT COUNT(*) FROM #LotByBatch WHERE LOT <> '' OR LOT IS NOT NULL)  
   BEGIN  
      SELECT @n_continue = 3  
      SELECT @b_Success = 0    
      SELECT @n_err = 99999  
      SELECT @c_errmsg = 'No Lot found for the batch. [nspInventoryHoldLot01]'  
   END  

   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      SELECT @lot = ''  

      DECLARE C_HOLD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      SELECT LOT, HOLD  
      FROM #LotByBatch   
      ORDER BY LOT  
      
      OPEN C_HOLD   

      FETCH NEXT FROM C_HOLD INTO @lot, @chold  
      WHILE @@FETCH_STATUS <> -1   
      BEGIN  
         IF @b_debug = 1   
         BEGIN  
            SELECT '@lot: ' + @lot   
            SELECT '@chold: ' + @chold   
         END  

         EXECUTE nspInventoryHold 
          @lot  
         ,''  
         ,''  
         ,'QC'  
         ,'1'  
         ,@b_Success OUTPUT  
         ,@n_err OUTPUT  
         ,@c_errmsg OUTPUT  

         IF @b_Success = 0   
         BEGIN  
            SELECT @n_continue = 3  
         END  

         FETCH NEXT FROM C_HOLD INTO @lot, @chold  
      END  
      CLOSE C_HOLD  
      DEALLOCATE C_HOLD   
      END -- Continue = 1  

      IF @n_continue = 3  
      BEGIN  
         IF (@@TRANCOUNT = 1) AND (@@TRANCOUNT > @n_starttcnt)  
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
      RETURN  
   END  
   ELSE  
   BEGIN  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  
END --MAIN  

GO