SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

                
/************************************************************************/                      
/* Stored Proc : ispArchiveSKU                                          */                      
/* Creation Date:                                                       */                      
/* Copyright: IDS                                                       */                      
/* Written by: James                                                    */                      
/*                                                                      */                      
/* Purpose: Purging SKU that has no inventory & no transaction          */                      
/*                                                                      */                      
/* Called By:  Back End                                                 */                      
/*                                                                      */                      
/* PVCS Version: 1.2                                                    */                      
/*                                                                      */                      
/* Version: 5.4                                                         */                      
/*                                                                      */                      
/* Data Modifications:                                                  */                      
/*                                                                      */                      
/* Updates:                                                             */                      
/* Date         Author    Ver  Purposes                                 */                      
/* 13-Feb-2008  James     1.0  Created                                  */                    
/* 31-Mar-2010  TLTING    1.2  Enhance copy to archive                  */              
/*                             Not check archive, remove temp table     */                
/************************************************************************/                      
CREATE PROCEDURE [dbo].[ispArchiveSKU]                      
    @c_StorerKey nvarchar(15)                  
,   @n_NoRecord  Int = 99999999                   
,   @c_CopyRowsToArchiveDatabase char(1)  = '1'              
               
AS                
BEGIN                       
   SET NOCOUNT ON                       
   SET ANSI_NULLS OFF                    
   SET QUOTED_IDENTIFIER OFF                       
   SET CONCAT_NULL_YIELDS_NULL OFF                      
                      
   DECLARE @n_continue    int,                      
      @n_starttcnt   int,       -- Holds the current transaction count                      
      @n_cnt         int,       -- Holds @@ROWCOUNT after certain operations                      
      @c_preprocess  nvarchar(250), -- preprocess                      
      @c_pstprocess  nvarchar(250), -- post process                      
      @n_err2        int,       -- For Additional Error Detection                      
      @b_debug       int,       -- Debug 0 - OFF, 1 - Show ALL, 2 - Map                      
      @b_success     int,                      
      @n_err         int,                           
      @c_errmsg      nvarchar(250),                      
      @errorcount    int                      
   DECLARE @cSKU     nvarchar( 20)                    
 , @n_count INT                  
                  
   SELECT @n_count = 0                  
                    
   SELECT @n_starttcnt=@@TRANCOUNT,                       
      @n_continue=1,                       
      @b_success=0,                      
      @n_err=0,                      
      @n_cnt = 0,                      
      @c_errmsg='',                      
      @n_err2=0                      
                       
   SELECT @b_debug = 0                    
   WHILE @@TRANCOUNT > 0           
      COMMIT TRAN           
          
      SELECT @n_count = Count(1)                  
    FROM SKU  WITH (NOLOCK)                     
      WHERE SKU.StorerKey = @c_StorerKey             
      AND SKU.Editdate < '20090101'       
             
          
      Print 'Target Archive SKU is ' + Cast(@n_count as varchar)          
   IF @n_Continue = 1                      
   BEGIN                    
      SET @n_count = 0          
      DECLARE CUR_ArchiveSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                     
      SELECT SKU.SKU                   
      FROM SKU  WITH (NOLOCK)                     
      WHERE SKU.StorerKey = @c_StorerKey             
      AND SKU.Editdate < '20090101'                
                  
      OPEN CUR_ArchiveSKU                 
              
     FETCH NEXT FROM CUR_ArchiveSKU INTO @cSKU                    
      WHILE @@FETCH_STATUS <> -1                    
      BEGIN                    
                   
                
  IF @n_Continue = 1 AND @c_CopyRowsToArchiveDatabase = '1'              
         BEGIN                      
            IF @b_debug = 1                    
               PRINT 'Start insert into archive..SKU with SKU ' + @cSKU                    
                
            IF NOT EXISTS ( SELECT 1 FROM ARCHIVE.dbo.SKU SKU With (NOLOCK)                  
                            WHERE StorerKey = @c_StorerKey                    
                               AND SKU = @cSKU  )                      
            BEGIN                   
            BEGIN TRAN                    
            INSERT INTO ARCHIVE.dbo.SKU                    
            (StorerKey, Sku, DESCR, SUSR1, SUSR2, SUSR3, SUSR4, SUSR5,                     
             MANUFACTURERSKU, RETAILSKU, ALTSKU, PACKKey, STDGROSSWGT,                     
             STDNETWGT, STDCUBE, TARE, CLASS, ACTIVE, SKUGROUP, Tariffkey,                     
             BUSR1, BUSR2, BUSR3, BUSR4, BUSR5, LOTTABLE01LABEL, LOTTABLE02LABEL,                     
             LOTTABLE03LABEL, LOTTABLE04LABEL, LOTTABLE05LABEL, NOTES1, NOTES2,                     
             PickCode, StrategyKey, CartonGroup, PutCode, PutawayLoc, PutawayZone,                     
             InnerPack, Cube, GrossWgt, NetWgt, ABC, CycleCountFrequency, LastCycleCount,                     
             ReorderPoint, ReorderQty, StdOrderCost, CarryCost, Price, Cost, ReceiptHoldCode,                     
             ReceiptInspectionLoc, OnReceiptCopyPackkey, TrafficCop, ArchiveCop, IOFlag,                     
             TareWeight, LotxIdDetailOtherlabel1, LotxIdDetailOtherlabel2, LotxIdDetailOtherlabel3,                     
             AvgCaseWeight, TolerancePct, SkuStatus, Length, Width, Height, weight, itemclass,                     
             ShelfLife, Facility, BUSR6, BUSR7, BUSR8, BUSR9, BUSR10, ReturnLoc, ReceiptLoc,                     
             AddDate, AddWho, EditDate, EditWho, archiveqty, XDockReceiptLoc, PrePackIndicator,                     
             PackQtyIndicator, StackFactor, IVAS, OVAS, Style, Color, Size, Measurement,              
    HazardousFlag, TemperatureFlag, ProductModel )                    
             SELECT                     
             StorerKey, Sku, DESCR, SUSR1, SUSR2, SUSR3, SUSR4, SUSR5,                     
             MANUFACTURERSKU, RETAILSKU, ALTSKU, PACKKey, STDGROSSWGT,                     
             STDNETWGT, STDCUBE, TARE, CLASS, ACTIVE, SKUGROUP, Tariffkey,                     
             BUSR1, BUSR2, BUSR3, BUSR4, BUSR5, LOTTABLE01LABEL, LOTTABLE02LABEL,                     
LOTTABLE03LABEL, LOTTABLE04LABEL, LOTTABLE05LABEL, NOTES1, NOTES2,                     
             PickCode, StrategyKey, CartonGroup, PutCode, PutawayLoc, PutawayZone,                     
             InnerPack, Cube, GrossWgt, NetWgt, ABC, CycleCountFrequency, LastCycleCount,                     
             ReorderPoint, ReorderQty, StdOrderCost, CarryCost, Price, Cost, ReceiptHoldCode,                     
             ReceiptInspectionLoc, OnReceiptCopyPackkey, TrafficCop, ArchiveCop, IOFlag,                   
             TareWeight, LotxIdDetailOtherlabel1, LotxIdDetailOtherlabel2, LotxIdDetailOtherlabel3,                     
             AvgCaseWeight, TolerancePct, SkuStatus, Length, Width, Height, weight, itemclass,                     
             ShelfLife, Facility, BUSR6, BUSR7, BUSR8, BUSR9, BUSR10, ReturnLoc, ReceiptLoc,                     
             AddDate, AddWho, EditDate, EditWho, archiveqty, XDockReceiptLoc, PrePackIndicator,                     
             PackQtyIndicator, StackFactor, IVAS, OVAS, Style, Color, Size, Measurement,              
        HazardousFlag, TemperatureFlag, ProductModel                     
             FROM SKU WITH (NOLOCK)                    
             WHERE StorerKey = @c_StorerKey                    
                AND SKU = @cSKU                    
                
            SELECT @n_err = @@ERROR                      
            IF @n_err <> 0                      
            BEGIN                      
               ROLLBACK TRAN                  
               SELECT @n_continue = 3                      
               SELECT @c_errmsg = CONVERT(nvarchar(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                      
              SELECT @c_errmsg='NSQL'+CONVERT(nvarchar(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '                      
               GOTO QUIT                    
            END              
            COMMIT TRAN                  
            END -- Not Exist Sku in Archive                  
         END                    
                
 -- Really no transaction occured for the past 2 yrs then start archive                    
         -- purge SKUxLOC                    
         IF @b_debug = 1                    
            PRINT 'Start archive with SKU ' + @cSKU                    
                
         IF @n_Continue = 1                      
         BEGIN                      
            IF @b_debug = 1                    
               PRINT 'Start archive SKUxLOC with SKU ' + @cSKU                    
            BEGIN TRAN           
            DELETE FROM SKUxLOC WITH (ROWLOCK)                    
            WHERE STORERKEY = @c_StorerKey                    
               AND SKU = @cSKU                    
                   
            SELECT @n_err = @@ERROR                      
            IF @n_err <> 0                      
            BEGIN                      
               ROLLBACK TRAN                  
               SELECT @n_continue = 3                      
               SELECT @c_errmsg = CONVERT(nvarchar(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                      
               SELECT @c_errmsg='NSQL'+CONVERT(nvarchar(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '                      
               GOTO QUIT                    
            END              
            COMMIT TRAN                  
         END                    
                
         -- purge LOTxLOCxID                    
         IF @n_Continue = 1                      
         BEGIN                      
            IF @b_debug = 1                    
               PRINT 'Start archive LOTxLOCxID with SKU ' + @cSKU                    
            BEGIN TRAN           
            DELETE FROM LOTxLOCxID WITH (ROWLOCK)                    
            WHERE STORERKEY = @c_StorerKey                    
               AND SKU = @cSKU                    
                
            SELECT @n_err = @@ERROR                      
            IF @n_err <> 0                      
            BEGIN                      
               ROLLBACK TRAN                  
               SELECT @n_continue = 3                      
               SELECT @c_errmsg = CONVERT(nvarchar(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                      
               SELECT @c_errmsg='NSQL'+CONVERT(nvarchar(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '                      
               GOTO QUIT                    
            END              
            COMMIT TRAN                  
         END                    
                
         -- purge LOT                    
         IF @n_Continue = 1                      
         BEGIN                      
            IF @b_debug = 1                    
               PRINT 'Start archive LOT with SKU ' + @cSKU                    
            BEGIN TRAN           
            DELETE FROM LOT WITH (ROWLOCK)                    
            WHERE STORERKEY = @c_StorerKey                    
   AND SKU = @cSKU                    
                
            SELECT @n_err = @@ERROR                      
            IF @n_err <> 0                      
            BEGIN                      
               ROLLBACK TRAN                  
               SELECT @n_continue = 3                      
               SELECT @c_errmsg = CONVERT(nvarchar(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                      
               SELECT @c_errmsg='NSQL'+CONVERT(nvarchar(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '                      
               GOTO QUIT                    
            END               
            COMMIT TRAN                 
         END                    
                
         -- purge LOTAttribute                    
         IF @n_Continue = 1                      
         BEGIN                      
            IF @b_debug = 1                    
               PRINT 'Start archive LOTAttribute with SKU ' + @cSKU                    
            BEGIN TRAN           
            DELETE FROM LOTAttribute WITH (ROWLOCK)                    
            WHERE STORERKEY = @c_StorerKey                    
               AND SKU = @cSKU                    
                
            SELECT @n_err = @@ERROR                      
            IF @n_err <> 0                      
            BEGIN                      
               ROLLBACK TRAN                  
               SELECT @n_continue = 3                      
               SELECT @c_errmsg = CONVERT(nvarchar(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                      
               SELECT @c_errmsg='NSQL'+CONVERT(nvarchar(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '                      
               GOTO QUIT                    
            END             
            COMMIT TRAN                   
         END                    
                
         -- purge UPC                    
         IF @n_Continue = 1                      
         BEGIN                      
            IF @b_debug = 1                    
               PRINT 'Start archive UPC with SKU ' + @cSKU                    
            BEGIN TRAN           
            DELETE FROM UPC WITH (ROWLOCK)                    
            WHERE STORERKEY = @c_StorerKey                    
               AND SKU = @cSKU                    
                
            SELECT @n_err = @@ERROR                      
            IF @n_err <> 0                      
            BEGIN                      
               ROLLBACK TRAN                  
               SELECT @n_continue = 3                      
               SELECT @c_errmsg = CONVERT(nvarchar(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                      
               SELECT @c_errmsg='NSQL'+CONVERT(nvarchar(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '                      
               GOTO QUIT                    
            END            
            COMMIT TRAN                    
         END                    
            
         -- purge UPC                    
         IF @n_Continue = 1                      
         BEGIN                      
            IF @b_debug = 1                 
               PRINT 'Start archive BillOfMaterial with SKU ' + @cSKU                    
            BEGIN TRAN           
            DELETE FROM BillOfMaterial WITH (ROWLOCK)                    
            WHERE STORERKEY = @c_StorerKey                    
               AND SKU = @cSKU                    
                
            SELECT @n_err = @@ERROR                      
            IF @n_err <> 0                      
            BEGIN                      
               ROLLBACK TRAN                  
               SELECT @n_continue = 3                      
               SELECT @c_errmsg = CONVERT(nvarchar(250),@n_err), @n_err=62103   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                      
               SELECT @c_errmsg='NSQL'+CONVERT(nvarchar(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '                      
               GOTO QUIT                    
            END                      
            COMMIT TRAN          
         END                
                
         -- purge SKU                    
         IF @n_Continue = 1                      
         BEGIN                      
            IF @b_debug = 1                    
               PRINT 'Start archive SKU with SKU ' + @cSKU                    
            BEGIN TRAN                 
            DELETE FROM SKU WITH (ROWLOCK)                    
            WHERE STORERKEY = @c_StorerKey                    
               AND SKU = @cSKU                    
                      
            SELECT @n_err = @@ERROR                      
            IF @n_err <> 0                      
            BEGIN                      
               ROLLBACK TRAN                  
               SELECT @n_continue = 3                      
               SELECT @c_errmsg = CONVERT(nvarchar(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                      
               SELECT @c_errmsg='NSQL'+CONVERT(nvarchar(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '                      
               GOTO QUIT                    
            END              
            COMMIT TRAN                  
         END                    
       --  COMMIT TRAN                  
                
                  
         SELECT @n_count = @n_count + 1                  
         IF @n_NoRecord <> 0 AND @n_count >= @n_NoRecord                  
            Break                  
                  
         FETCH NEXT FROM CUR_ArchiveSKU INTO @cSKU                    
      END   -- while @@fetch_status                    
                  
      QUIT:                   
      CLOSE CUR_ArchiveSKU                    
      DEALLOCATE CUR_ArchiveSKU                    
   END   -- @n_continue=1                    
    
   WHILE @@TRANCOUNT > 0                     
            COMMIT TRAN       
                
   WHILE @@TRANCOUNT < @n_starttcnt                      
   BEGIN                      
      BEGIN TRAN                      
   END                    
                  
   IF @n_continue=3  -- Error Occured - Process And Return                      
   BEGIN                      
      SELECT @b_success = 0                      
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
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012                      
      RETURN                      
   END                      
   ELSE                      
   BEGIN                      
      SELECT @b_success = 1                      
      WHILE @@TRANCOUNT > @n_starttcnt                      
      BEGIN     
         COMMIT TRAN                      
      END                      
   END                      
END -- procedure 


GO