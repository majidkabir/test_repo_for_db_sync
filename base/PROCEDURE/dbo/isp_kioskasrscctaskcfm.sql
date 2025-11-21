SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_KioskASRSCCTaskCfm                             */  
/* Creation Date: 27-Jan-2015                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: Confirm CC Task - Task Completed;                           */  
/*        : SOS#315474 - Project Merlion - Exceed GTM Kiosk Module      */  
/* Called By: cb_complete                                               */  
/*          : u_kiosk_asrscc_b.cb_complete.click event                  */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 6.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/************************************************************************/  
CREATE PROC [dbo].[isp_KioskASRSCCTaskCfm]   
            @c_JobKey         NVARCHAR(10) = ''  
         ,  @c_TaskDetailkey  NVARCHAR(10)  
         ,  @c_ID             NVARCHAR(18)  
         ,  @c_CCKey          NVARCHAR(10)  
         ,  @c_CCSheetNo      NVARCHAR(10)  
         ,  @c_CCDetailkey    NVARCHAR(10)  
         ,  @c_Storerkey      NVARCHAR(20)  
         ,  @c_Sku            NVARCHAR(20)  
         ,  @c_Lottable01     NVARCHAR(18)  
         ,  @c_Lottable02     NVARCHAR(18)  
         ,  @c_Lottable03     NVARCHAR(18)  
         ,  @dt_Lottable04    DATETIME  
         ,  @dt_Lottable05    DATETIME   
         ,  @c_Lottable06     NVARCHAR(30)  
         ,  @c_Lottable07     NVARCHAR(30)  
         ,  @c_Lottable08     NVARCHAR(30)  
         ,  @c_Lottable09     NVARCHAR(30)  
         ,  @c_Lottable10     NVARCHAR(30)  
         ,  @c_Lottable11     NVARCHAR(30)  
         ,  @c_Lottable12     NVARCHAR(30)  
         ,  @dt_Lottable13    DATETIME  
         ,  @dt_Lottable14    DATETIME  
         ,  @dt_Lottable15    DATETIME  
         ,  @n_CountedQty     INT  
         ,  @c_taskstatus     NVARCHAR(10) OUTPUT  
         ,  @b_Success        INT = 0  OUTPUT   
         ,  @n_err            INT = 0  OUTPUT   
         ,  @c_errmsg         NVARCHAR(215) = '' OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @n_StartTCnt          INT  
         , @n_Continue           INT   
  
         , @n_FinalizeStage      INT  
         , @c_NewCCDetailKey     NVARCHAR(10)  
         , @c_Lot                NVARCHAR(10)  
         , @c_Loc                NVARCHAR(10)  
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
   SET @n_err      = 0  
   SET @c_errmsg   = ''  
   SET @c_Lot      = ''  
  
   SELECT @n_FinalizeStage = FinalizeStage   
   FROM STOCKTAKESHEETPARAMETERS WITH (NOLOCK)  
   WHERE StockTakekey = @c_CCKey  
  
   BEGIN TRAN    
   IF ISNULL(@c_CCDetailkey,'') = ''  
   BEGIN  
      SET @c_Loc = ''  
      SELECT TOP 1 @c_Loc = LOC  
      FROM LOTxLOCxID WITH (NOLOCK)  
      WHERE ID = @c_ID  
      AND Qty > 0  
  
      SET @b_success = 1      
      EXECUTE   nspg_getkey      
               'CCDetailKey'      
              , 10      
              , @c_NewCCDetailKey   OUTPUT      
              , @b_success          OUTPUT      
              , @n_err            OUTPUT      
              , @c_errmsg           OUTPUT   
  
      IF NOT @b_success = 1      
      BEGIN      
         SET @n_continue = 3      
         SET @n_err = 61005  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get CCDetailKey Failed. (isp_KioskASRSCCTaskCfm)'   
         GOTO QUIT_SP    
      END    
  
      INSERT INTO CCDETAIL (                                                                    
            CCKey   
         ,  CCSheetNo                                                                              
         ,  CCDetailKey                                                                         
         ,  Storerkey                                                                           
         ,  Sku                                                                                 
         ,  Lot                                                                                 
         ,  Loc                                                                                 
         ,  ID                                                                                  
         ,  Qty                                                                                 
         ,  Qty_Cnt2                                                                            
         ,  Qty_Cnt3                                                                            
         ,  Lottable01                                                                          
         ,  Lottable01_Cnt2                                                                     
         ,  Lottable01_Cnt3                                                                     
         ,  Lottable02                                                                          
         ,  Lottable02_Cnt2                                                                     
         ,  Lottable02_Cnt3                                                                     
         ,  Lottable03                                                                          
         ,  Lottable03_Cnt2                                                                     
         ,  Lottable03_Cnt3                                                                     
         ,  Lottable04                                                                          
         ,  Lottable04_Cnt2                                                                     
         ,  Lottable04_Cnt3                                                                     
         ,  Lottable05                                                                          
         ,  Lottable05_Cnt2                                                                     
         ,  Lottable05_Cnt3                                                                     
         ,  Lottable06                                                                          
         ,  Lottable06_Cnt2                                                                     
         ,  Lottable06_Cnt3                                                                     
         ,  Lottable07                                                                          
         ,  Lottable07_Cnt2                                                                     
         ,  Lottable07_Cnt3                                                                     
         ,  Lottable08                                                                          
         ,  Lottable08_Cnt2                                                                     
         ,  Lottable08_Cnt3                                                                     
         ,  Lottable09                                                                          
         ,  Lottable09_Cnt2                                                                     
         ,  Lottable09_Cnt3                                                                     
         ,  Lottable10                                                                          
   ,  Lottable10_Cnt2                                                                     
         ,  Lottable10_Cnt3                                                                     
         ,  Lottable11                                                                          
         ,  Lottable11_Cnt2                                                                     
         ,  Lottable11_Cnt3                                                                     
         ,  Lottable12                                                                          
         ,  Lottable12_Cnt2                                                                     
         ,  Lottable12_Cnt3                                                                     
         ,  Lottable13                                                                          
         ,  Lottable13_Cnt2                                                                     
         ,  Lottable13_Cnt3                                                                     
         ,  Lottable14                                                                          
         ,  Lottable14_Cnt2                                                                     
         ,  Lottable14_Cnt3                                                                     
         ,  Lottable15                                                                          
         ,  Lottable15_Cnt2                                                                     
         ,  Lottable15_Cnt3                                                                     
         ,  Counted_Cnt1   
         ,  Counted_Cnt2   
         ,  Counted_Cnt3   
         ,  EditWho_Cnt1  
         ,  EditWho_Cnt2  
         ,  EditWho_Cnt3  
         ,  EditDate_Cnt1  
         ,  EditDate_Cnt2  
         ,  EditDate_Cnt3  
         ,  Status                                                                 
         )                                                                                      
      VALUES  
         (  @c_CCKey  
         ,  @c_CCSheetNo                                                                                 
         ,  @c_NewCCDetailKey    
         ,  @c_Storerkey                                                                           
         ,  @c_Sku                                                                                 
         ,  @c_Lot                                                                                 
         ,  @c_Loc                                                                                 
         ,  @c_ID                                                                                             
       ,  CASE WHEN @n_FinalizeStage = 0 THEN @n_CountedQty ELSE 0 END                      
         ,  CASE WHEN @n_FinalizeStage = 1 THEN @n_CountedQty ELSE 0 END                 
         ,  CASE WHEN @n_FinalizeStage = 2 THEN @n_CountedQty ELSE 0 END                 
         ,  CASE WHEN @n_FinalizeStage = 0 THEN @c_Lottable01 ELSE '' END               
         ,  CASE WHEN @n_FinalizeStage = 1 THEN @c_Lottable01 ELSE '' END          
         ,  CASE WHEN @n_FinalizeStage = 2 THEN @c_Lottable01 ELSE '' END          
         ,  CASE WHEN @n_FinalizeStage = 0 THEN @c_Lottable02 ELSE '' END               
         ,  CASE WHEN @n_FinalizeStage = 1 THEN @c_Lottable02 ELSE '' END          
         ,  CASE WHEN @n_FinalizeStage = 2 THEN @c_Lottable02 ELSE '' END          
         ,  CASE WHEN @n_FinalizeStage = 0 THEN @c_Lottable03 ELSE '' END               
         ,  CASE WHEN @n_FinalizeStage = 1 THEN @c_Lottable03 ELSE '' END          
         ,  CASE WHEN @n_FinalizeStage = 2 THEN @c_Lottable03 ELSE '' END          
         ,  CASE WHEN @n_FinalizeStage = 0 THEN @dt_Lottable04 ELSE NULL END               
         ,  CASE WHEN @n_FinalizeStage = 1 THEN @dt_Lottable04 ELSE NULL END          
         ,  CASE WHEN @n_FinalizeStage = 2 THEN @dt_Lottable04 ELSE NULL END          
         ,  CASE WHEN @n_FinalizeStage = 0 THEN @dt_Lottable05 ELSE NULL END               
         ,  CASE WHEN @n_FinalizeStage = 1 THEN @dt_Lottable05 ELSE NULL END          
         ,  CASE WHEN @n_FinalizeStage = 2 THEN @dt_Lottable05 ELSE NULL END          
         ,  CASE WHEN @n_FinalizeStage = 0 THEN @c_Lottable06 ELSE '' END               
         ,  CASE WHEN @n_FinalizeStage = 1 THEN @c_Lottable06 ELSE '' END          
         ,  CASE WHEN @n_FinalizeStage = 2 THEN @c_Lottable06 ELSE '' END          
         ,  CASE WHEN @n_FinalizeStage = 0 THEN @c_Lottable07 ELSE '' END               
         ,  CASE WHEN @n_FinalizeStage = 1 THEN @c_Lottable07 ELSE '' END          
         ,  CASE WHEN @n_FinalizeStage = 2 THEN @c_Lottable07 ELSE '' END          
         ,  CASE WHEN @n_FinalizeStage = 0 THEN @c_Lottable08 ELSE '' END               
         ,  CASE WHEN @n_FinalizeStage = 1 THEN @c_Lottable08 ELSE '' END          
         ,  CASE WHEN @n_FinalizeStage = 2 THEN @c_Lottable08 ELSE '' END          
         ,  CASE WHEN @n_FinalizeStage = 0 THEN @c_Lottable09 ELSE '' END               
         ,  CASE WHEN @n_FinalizeStage = 1 THEN @c_Lottable09 ELSE '' END          
         ,  CASE WHEN @n_FinalizeStage = 2 THEN @c_Lottable09 ELSE '' END          
         ,  CASE WHEN @n_FinalizeStage = 0 THEN @c_Lottable10 ELSE '' END               
         ,  CASE WHEN @n_FinalizeStage = 1 THEN @c_Lottable10 ELSE '' END          
         ,  CASE WHEN @n_FinalizeStage = 2 THEN @c_Lottable10 ELSE '' END          
         ,  CASE WHEN @n_FinalizeStage = 0 THEN @c_Lottable11 ELSE '' END               
         ,  CASE WHEN @n_FinalizeStage = 1 THEN @c_Lottable11 ELSE '' END          
         ,  CASE WHEN @n_FinalizeStage = 2 THEN @c_Lottable11 ELSE '' END          
         ,  CASE WHEN @n_FinalizeStage = 0 THEN @c_Lottable12 ELSE '' END               
         ,  CASE WHEN @n_FinalizeStage = 1 THEN @c_Lottable12 ELSE '' END          
         ,  CASE WHEN @n_FinalizeStage = 2 THEN @c_Lottable12 ELSE '' END          
         ,  CASE WHEN @n_FinalizeStage = 0 THEN @dt_Lottable13 ELSE NULL END               
         ,  CASE WHEN @n_FinalizeStage = 1 THEN @dt_Lottable13 ELSE NULL END          
         ,  CASE WHEN @n_FinalizeStage = 2 THEN @dt_Lottable13 ELSE NULL END          
         ,  CASE WHEN @n_FinalizeStage = 0 THEN @dt_Lottable14 ELSE NULL END               
         ,  CASE WHEN @n_FinalizeStage = 1 THEN @dt_Lottable14 ELSE NULL END          
         ,  CASE WHEN @n_FinalizeStage = 2 THEN @dt_Lottable14 ELSE NULL END          
         ,  CASE WHEN @n_FinalizeStage = 0 THEN @dt_Lottable15 ELSE NULL END               
         ,  CASE WHEN @n_FinalizeStage = 1 THEN @dt_Lottable15 ELSE NULL END          
         ,  CASE WHEN @n_FinalizeStage = 2 THEN @dt_Lottable15 ELSE NULL END          
         ,  CASE WHEN @n_FinalizeStage = 0 THEN '1' ELSE '0' END                       
         ,  CASE WHEN @n_FinalizeStage = 1 THEN '1' ELSE '0' END                  
         ,  CASE WHEN @n_FinalizeStage = 2 THEN '1' ELSE '0' END   
         ,  CASE WHEN @n_FinalizeStage = 0 THEN SUSER_NAME() ELSE NULL END  
         ,  CASE WHEN @n_FinalizeStage = 1 THEN SUSER_NAME() ELSE NULL END  
         ,  CASE WHEN @n_FinalizeStage = 2 THEN SUSER_NAME() ELSE NULL END  
         ,  CASE WHEN @n_FinalizeStage = 0 THEN GETDATE()    ELSE NULL END  
         ,  CASE WHEN @n_FinalizeStage = 1 THEN GETDATE()    ELSE NULL END  
         ,  CASE WHEN @n_FinalizeStage = 2 THEN GETDATE()    ELSE NULL END  
  
         , '4'                 
         )    
  
     SET @n_err = @@ERROR     
  
      IF @n_err <> 0      
      BEGIN    
         SET @n_continue = 3      
         SET @n_err = 61010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': INSERT CCDETAIL Failed. (isp_KioskASRSCCTaskCfm)'   
         GOTO QUIT_SP  
      END                                  
   END  
   ELSE -- Update   
   BEGIN  
      UPDATE CCDETAIL WITH (ROWLOCK)  
      SET   Qty               = CASE WHEN @n_FinalizeStage = 0 THEN @n_CountedQty ELSE Qty END  
         ,  Qty_Cnt2          = CASE WHEN @n_FinalizeStage = 1 THEN @n_CountedQty ELSE Qty_Cnt2 END  
         ,  Qty_Cnt3          = CASE WHEN @n_FinalizeStage = 2 THEN @n_CountedQty ELSE Qty_Cnt3 END  
--         ,  Lottable01        = CASE WHEN @n_FinalizeStage = 0 THEN @c_Lottable01 ELSE Lottable01 END      
--         ,  Lottable01_Cnt2   = CASE WHEN @n_FinalizeStage = 1 THEN @c_Lottable01 ELSE Lottable01_Cnt2 END  
--         ,  Lottable01_Cnt3   = CASE WHEN @n_FinalizeStage = 2 THEN @c_Lottable01 ELSE Lottable01_Cnt3 END  
--         ,  Lottable02        = CASE WHEN @n_FinalizeStage = 0 THEN @c_Lottable02 ELSE Lottable02 END   
--         ,  Lottable02_Cnt2   = CASE WHEN @n_FinalizeStage = 1 THEN @c_Lottable02 ELSE Lottable02_Cnt2 END  
--         ,  Lottable02_Cnt3   = CASE WHEN @n_FinalizeStage = 2 THEN @c_Lottable02 ELSE Lottable02_Cnt3 END  
--         ,  Lottable03        = CASE WHEN @n_FinalizeStage = 0 THEN @c_Lottable03 ELSE Lottable03 END      
--         ,  Lottable03_Cnt2   = CASE WHEN @n_FinalizeStage = 1 THEN @c_Lottable03 ELSE Lottable03_Cnt2 END  
--         ,  Lottable03_Cnt3   = CASE WHEN @n_FinalizeStage = 2 THEN @c_Lottable03 ELSE Lottable03_Cnt3 END  
--         ,  Lottable04        = CASE WHEN @n_FinalizeStage = 0 THEN @dt_Lottable04 ELSE Lottable04 END    
--         ,  Lottable04_Cnt2   = CASE WHEN @n_FinalizeStage = 1 THEN @dt_Lottable04 ELSE Lottable04_Cnt2 END  
--         ,  Lottable04_Cnt3   = CASE WHEN @n_FinalizeStage = 2 THEN @dt_Lottable04 ELSE Lottable04_Cnt3 END  
--         ,  Lottable05        = CASE WHEN @n_FinalizeStage = 0 THEN @dt_Lottable05 ELSE Lottable05 END     
--         ,  Lottable05_Cnt2   = CASE WHEN @n_FinalizeStage = 1 THEN @dt_Lottable05 ELSE Lottable05_Cnt2 END  
--         ,  Lottable05_Cnt3   = CASE WHEN @n_FinalizeStage = 2 THEN @dt_Lottable05 ELSE Lottable05_Cnt3 END  
--         ,  Lottable06        = CASE WHEN @n_FinalizeStage = 0 THEN @c_Lottable06 ELSE Lottable06 END  
--         ,  Lottable06_Cnt2   = CASE WHEN @n_FinalizeStage = 1 THEN @c_Lottable06 ELSE Lottable06_Cnt2 END  
--         ,  Lottable06_Cnt3   = CASE WHEN @n_FinalizeStage = 2 THEN @c_Lottable06 ELSE Lottable06_Cnt3 END  
--         ,  Lottable07        = CASE WHEN @n_FinalizeStage = 0 THEN @c_Lottable07 ELSE Lottable07 END   
--         ,  Lottable07_Cnt2   = CASE WHEN @n_FinalizeStage = 1 THEN @c_Lottable07 ELSE Lottable07_Cnt2 END  
--         ,  Lottable07_Cnt3   = CASE WHEN @n_FinalizeStage = 2 THEN @c_Lottable07 ELSE Lottable07_Cnt3 END  
--         ,  Lottable08        = CASE WHEN @n_FinalizeStage = 0 THEN @c_Lottable08 ELSE Lottable08 END  
--         ,  Lottable08_Cnt2   = CASE WHEN @n_FinalizeStage = 1 THEN @c_Lottable08 ELSE Lottable08_Cnt2 END  
--         ,  Lottable08_Cnt3   = CASE WHEN @n_FinalizeStage = 2 THEN @c_Lottable08 ELSE Lottable08_Cnt3 END       
--         ,  Lottable09        = CASE WHEN @n_FinalizeStage = 0 THEN @c_Lottable09 ELSE Lottable09 END   
--         ,  Lottable09_Cnt2   = CASE WHEN @n_FinalizeStage = 1 THEN @c_Lottable09 ELSE Lottable09_Cnt2 END  
--         ,  Lottable09_Cnt3   = CASE WHEN @n_FinalizeStage = 2 THEN @c_Lottable09 ELSE Lottable09_Cnt3 END  
--         ,  Lottable10        = CASE WHEN @n_FinalizeStage = 0 THEN @c_Lottable10 ELSE Lottable10 END   
--         ,  Lottable10_Cnt2   = CASE WHEN @n_FinalizeStage = 1 THEN @c_Lottable10 ELSE Lottable10_Cnt2 END  
--         ,  Lottable10_Cnt3   = CASE WHEN @n_FinalizeStage = 2 THEN @c_Lottable10 ELSE Lottable10_Cnt3 END     
--         ,  Lottable11        = CASE WHEN @n_FinalizeStage = 0 THEN @c_Lottable11 ELSE Lottable11 END  
--         ,  Lottable11_Cnt2   = CASE WHEN @n_FinalizeStage = 1 THEN @c_Lottable11 ELSE Lottable11_Cnt2 END  
--         ,  Lottable11_Cnt3   = CASE WHEN @n_FinalizeStage = 2 THEN @c_Lottable11 ELSE Lottable11_Cnt3 END   
--         ,  Lottable12        = CASE WHEN @n_FinalizeStage = 0 THEN @c_Lottable12 ELSE Lottable12 END   
--         ,  Lottable12_Cnt2   = CASE WHEN @n_FinalizeStage = 1 THEN @c_Lottable12 ELSE Lottable12_Cnt2 END  
--         ,  Lottable12_Cnt3   = CASE WHEN @n_FinalizeStage = 2 THEN @c_Lottable12 ELSE Lottable12_Cnt3 END  
--         ,  Lottable13        = CASE WHEN @n_FinalizeStage = 0 THEN @dt_Lottable13 ELSE Lottable13 END   
--         ,  Lottable13_Cnt2   = CASE WHEN @n_FinalizeStage = 1 THEN @dt_Lottable13 ELSE Lottable13_Cnt2 END  
--         ,  Lottable13_Cnt3   = CASE WHEN @n_FinalizeStage = 2 THEN @dt_Lottable13 ELSE Lottable13_Cnt3 END  
--         ,  Lottable14        = CASE WHEN @n_FinalizeStage = 0 THEN @dt_Lottable14 ELSE Lottable14 END  
--         ,  Lottable14_Cnt2   = CASE WHEN @n_FinalizeStage = 1 THEN @dt_Lottable14 ELSE Lottable14_Cnt2 END  
--         ,  Lottable14_Cnt3   = CASE WHEN @n_FinalizeStage = 2 THEN @dt_Lottable14 ELSE Lottable14_Cnt3 END   
--         ,  Lottable15        = CASE WHEN @n_FinalizeStage = 0 THEN @dt_Lottable15 ELSE Lottable15 END   
--         ,  Lottable15_Cnt2   = CASE WHEN @n_FinalizeStage = 1 THEN @dt_Lottable15 ELSE Lottable15_Cnt2 END  
--         ,  Lottable15_Cnt3   = CASE WHEN @n_FinalizeStage = 2 THEN @dt_Lottable15 ELSE Lottable15_Cnt3 END  
  
         ,  Counted_Cnt1      = CASE WHEN @n_FinalizeStage = 0 THEN '1' ELSE Counted_Cnt1 END  
         ,  Counted_Cnt2      = CASE WHEN @n_FinalizeStage = 1 THEN '1' ELSE Counted_Cnt2 END  
         ,  Counted_Cnt3      = CASE WHEN @n_FinalizeStage = 2 THEN '1' ELSE Counted_Cnt3 END  
         ,  EditWho_Cnt1      = CASE WHEN @n_FinalizeStage = 0 THEN SUSER_NAME() ELSE EditWho_Cnt1 END  
         ,  EditWho_Cnt2      = CASE WHEN @n_FinalizeStage = 1 THEN SUSER_NAME() ELSE EditWho_Cnt2 END  
         ,  EditWho_Cnt3      = CASE WHEN @n_FinalizeStage = 2 THEN SUSER_NAME() ELSE EditWho_Cnt3 END  
         ,  EditDate_Cnt1     = CASE WHEN @n_FinalizeStage = 0 THEN GETDATE()    ELSE EditDate_Cnt1 END  
         ,  EditDate_Cnt2     = CASE WHEN @n_FinalizeStage = 1 THEN GETDATE()    ELSE EditDate_Cnt2 END  
         ,  EditDate_Cnt3     = CASE WHEN @n_FinalizeStage = 2 THEN GETDATE()    ELSE EditDate_Cnt3 END  
         ,  Status = '2'   
         ,  EditWho= SUSER_NAME()  
         ,  EditDate=GETDATE()  
         ,  Trafficcop = NULL  
      WHERE CCDetailkey  = @c_CCDetailkey  
  
      SET @n_err = @@ERROR     
  
      IF @n_err <> 0      
      BEGIN    
         SET @n_continue = 3      
         SET @n_err = 61015   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update CCDETAIL Failed. (isp_KioskASRSCCTaskCfm)'   
         GOTO QUIT_SP  
      END   
   END  
  
   IF NOT EXISTS( SELECT 1  
                  FROM CCDETAIL WITH (NOLOCK)  
                  WHERE CCKey = @c_CCKey  
                  AND   ID    = @c_ID  
                  AND   Counted_Cnt1 = CASE WHEN @n_FinalizeStage = 0 THEN '0' ELSE Counted_Cnt1 END  
                  AND   Counted_Cnt2 = CASE WHEN @n_FinalizeStage = 1 THEN '0' ELSE Counted_Cnt2 END  
                  AND   Counted_Cnt3 = CASE WHEN @n_FinalizeStage = 2 THEN '0' ELSE Counted_Cnt3 END  
                  AND   CCDETAIL.SystemQty <> CASE @n_FinalizeStage  WHEN 0 THEN -99999    --NJOW
             WHEN 1 THEN CCDETAIL.Qty  
                                                       WHEN 2 THEN CCDETAIL.Qty_Cnt2  
                                                       END  
                ) AND  
      EXISTS ( SELECT 1   
               FROM TASKDETAIL WITH (NOLOCK)  
               WHERE TaskdetailKey = @c_Taskdetailkey  
               AND   Status < '9'  
             )  
   BEGIN  
      UPDATE TASKDETAIL WITH (ROWLOCK)  
      SET Status = '9'  
         ,EditWho= SUSER_NAME()  
         ,EditDate=GETDATE()  
         ,Trafficcop = NULL  
      WHERE TaskdetailKey = @c_Taskdetailkey  
  
      SET @n_err = @@ERROR     
  
      IF @n_err <> 0      
      BEGIN    
         SET @n_continue = 3      
         SET @n_err = 61020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TASKDETAIL Failed. (isp_KioskASRSCCTaskCfm)'   
         GOTO QUIT_SP  
      END   
  
      UPDATE TASKDETAIL WITH (ROWLOCK)  
      SET Status = '4'  
         ,EditWho= SUSER_NAME()  
         ,EditDate=GETDATE()  
         ,Trafficcop = NULL  
      WHERE TaskDetailkey = @c_Jobkey  
      AND   TaskType = 'GTMJOB'  
  
      SET @n_err = @@ERROR     
  
      IF @n_err <> 0      
      BEGIN    
         SET @n_continue = 3      
         SET @n_err = 61025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TASKDETAIL Failed. (isp_KioskASRSCCTaskCfm)'   
         GOTO QUIT_SP  
      END   
   END  
  
   SELECT @c_TaskStatus = Status  
   FROM TASKDETAIL WITH (NOLOCK)  
   WHERE TaskdetailKey = @c_Taskdetailkey  
QUIT_SP:  
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_KioskASRSCCTaskCfm'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
  
END -- procedure

GO