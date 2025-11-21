SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Trigger:  ispGetLottable1to4                                         */    
/* Creation Date: 23-Aug-2013                                           */    
/* Copyright: IDS                                                       */    
/* Written by: Chew KP                                                  */    
/*                                                                      */    
/* Purpose:  Generate Receiptdetail Lottable01 to Lottable04            */    
/*                                                                      */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver.  Purposes                                */    
/* 13-Nov-2013  ChewKP    1.1   SOS#294699 Use Codelkup to control      */    
/*                              Storer that use this features (ChewKP01)*/    
/* 21-May-2014  TKLIM     1.1   Added Lottables 06-15                   */  
/* 14-Jan-2015  CSCHONG   1.2   Add new input parameter (CS01)          */  
/* 10-04-2015   James     1.3   SOS337674-Show carton lottable (james01)*/
/************************************************************************/    
    
CREATE PROCEDURE [dbo].[ispGetLottable1to4]    
     @c_Storerkey          NVARCHAR(15)  
   , @c_Sku                NVARCHAR(20)  
   , @c_Lottable01Value    NVARCHAR(18)  
   , @c_Lottable02Value    NVARCHAR(18)  
   , @c_Lottable03Value    NVARCHAR(18)  
   , @dt_Lottable04Value   DATETIME  
   , @dt_Lottable05Value   DATETIME  
   , @c_Lottable06Value    NVARCHAR(30)   = ''  
   , @c_Lottable07Value    NVARCHAR(30)   = ''  
   , @c_Lottable08Value    NVARCHAR(30)   = ''  
   , @c_Lottable09Value    NVARCHAR(30)   = ''  
   , @c_Lottable10Value    NVARCHAR(30)   = ''  
   , @c_Lottable11Value    NVARCHAR(30)   = ''  
   , @c_Lottable12Value    NVARCHAR(30)   = ''  
   , @dt_Lottable13Value   DATETIME       = NULL  
   , @dt_Lottable14Value   DATETIME       = NULL  
   , @dt_Lottable15Value   DATETIME       = NULL  
   , @c_Lottable01         NVARCHAR(18)            OUTPUT  
   , @c_Lottable02         NVARCHAR(18)            OUTPUT  
   , @c_Lottable03         NVARCHAR(18)            OUTPUT  
   , @dt_Lottable04        DATETIME                OUTPUT  
   , @dt_Lottable05        DATETIME                OUTPUT  
   , @c_Lottable06         NVARCHAR(30)   = ''     OUTPUT  
   , @c_Lottable07         NVARCHAR(30)   = ''     OUTPUT  
   , @c_Lottable08         NVARCHAR(30)   = ''     OUTPUT  
   , @c_Lottable09         NVARCHAR(30)   = ''     OUTPUT  
   , @c_Lottable10         NVARCHAR(30)   = ''     OUTPUT  
   , @c_Lottable11         NVARCHAR(30)   = ''     OUTPUT  
   , @c_Lottable12         NVARCHAR(30)   = ''     OUTPUT  
   , @dt_Lottable13        DATETIME       = NULL   OUTPUT  
   , @dt_Lottable14        DATETIME       = NULL   OUTPUT  
   , @dt_Lottable15        DATETIME       = NULL   OUTPUT  
   , @b_Success            int            = 1      OUTPUT  
   , @n_Err                int            = 0      OUTPUT  
   , @c_Errmsg             NVARCHAR(250)  = ''     OUTPUT  
   , @c_Sourcekey          NVARCHAR(15)   = ''    
   , @c_Sourcetype         NVARCHAR(20)   = ''     
   , @c_LottableLabel      NVARCHAR(20)   = ''   
   , @c_type               NVARCHAR(10) = ''     --(CS01)  
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE    
      @c_Lottable01Label   NVARCHAR( 20),    
      @c_ReceiptKey        NVARCHAR( 10),    
      @c_ReceiptLineNo     NVARCHAR( 5),    
      @c_CodeLkupStorerKey NVARCHAR( 15),    
      @c_ListName          NVARCHAR( 10),    
      @c_CheckType         NVARCHAR( 10),    
      @n_RowCount          INT    
    
   DECLARE @n_continue     INT,    
           @b_debug        INT, 
           @n_Func         INT, 
           @c_LOT          NVARCHAR( 10), -- (james01)
           @c_DropID       NVARCHAR( 20)  -- (james01)
           
               
    
   SELECT @n_continue = 1, @b_success = 1, @n_Err = 0, @b_debug = 0    
   SELECT @c_Lottable01 = '',    
          @c_Lottable02 = '',    
          @c_Lottable03 = '',    
          @c_Lottable06 = '',  
          @c_Lottable07 = '',  
          @c_Lottable08 = '',  
          @c_Lottable09 = '',  
          @c_Lottable10 = '',  
          @c_Lottable11 = '',  
          @c_Lottable12 = '',  
          --@dt_Lottable04 = NULL,    
          --@dt_Lottable05 = NULL,    
          @n_Rowcount = 0    

   SELECT @n_Func = Func FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE UserName = sUser_sName()

   SET @c_ReceiptKey    = LEFT(@c_SourceKey,10)     
   SET @c_ReceiptLineNo = RIGHT(@c_SourceKey,5)     
    
     
   IF @c_Sourcetype NOT IN ('RDTRECEIPT', 'RDTPICK')  -- (james01)
   BEGIN  
      GOTO QUIT   
   END    
     
   -- Hardcode StorerKey for the Moments as PB , RDT need CR to enhance the Lottable Request    
   --IF ISNULL(RTRIM(@c_StorerKey),'')  <> 'FBTTH' (ChewKP01)    
   IF NOT EXISTS ( SELECT 1 From dbo.Codelkup WITH (NOLOCK) WHERE ListName = 'LOTBL1TO4' AND StorerKey = @c_Storerkey)     
   BEGIN    
      GOTO QUIT    
   END    
   SET @c_CheckType = ''    
    
   SELECT @c_CheckType = Code     
   FROM dbo.CodeLKUP WITH (NOLOCK)     
   WHERE StorerKey = @c_StorerKey     
   AND ListName = 'LOTBL1TO4'    
    
       
       
   IF @c_CheckType = 'IML'    
   BEGIN    
       SELECT TOP 1 @c_Lottable01 = ISNULL(Lottable01,'')   
          , @c_Lottable02 = ISNULL(Lottable02,'')    
          , @c_Lottable03 = ISNULL(Lottable03,'')    
          , @dt_Lottable04 = Lottable04    
      FROM dbo.ReceiptDetail WITH (NOLOCK)    
      WHERE StorerKey      = @c_Storerkey    
            AND ReceiptKey = @c_ReceiptKey    
            AND SKU        = @c_Sku    
            --AND BeforeReceivedQty > 0     
      ORDER BY ReceiptLineNumber      
   END    
   ELSE IF @c_CheckType = 'RDT'  
   BEGIN
      IF @c_Sourcetype = 'RDTPICK' AND @n_Func = 904 -- (james01)
      BEGIN
         -- Get the carton id
         SELECT @c_DropID = V_String2
         FROM RDT.RDTMOBREC WITH (NOLOCK) 
         WHERE UserName = sUser_sName()
         
         SELECT TOP 1 @c_LOT = LOT 
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @c_StorerKey
         AND   SKU = @c_SKU
         AND   DropID = @c_DropID

         SELECT  
            @c_Lottable01 = ISNULL(Lottable01,'')   
          , @c_Lottable02 = ISNULL(Lottable02,'')  
          , @c_Lottable03 = ISNULL(Lottable03,'')  
          , @dt_Lottable04 = Lottable04          
         FROM LOTATTRIBUTE (NOLOCK) 
         WHERE LOT = @c_LOT
      END
      ELSE   
      BEGIN    
         SELECT TOP 1 @c_Lottable01 = ISNULL(Lottable01,'')     
             , @c_Lottable02 = ISNULL(Lottable02,'')    
             , @c_Lottable03 = ISNULL(Lottable03,'')    
             , @dt_Lottable04 = Lottable04    
         FROM dbo.ReceiptDetail WITH (NOLOCK)    
         WHERE StorerKey      = @c_Storerkey    
               AND ReceiptKey = @c_ReceiptKey    
               AND SKU        = @c_Sku    
               AND BeforeReceivedQty > 0     
         ORDER BY ReceiptLineNumber DESC    
             
         SET @n_RowCount = @@Rowcount    
       
         -- If Not Record / Not Yet Receive get Original Lottable Values    
         IF @n_RowCount = 0     
         BEGIN    
            SELECT TOP 1 @c_Lottable01 = ISNULL(Lottable01,'')     
             , @c_Lottable02 = ISNULL(Lottable02,'')    
             , @c_Lottable03 = ISNULL(Lottable03,'')    
             , @dt_Lottable04 = Lottable04    
            FROM dbo.ReceiptDetail WITH (NOLOCK)    
            WHERE StorerKey      = @c_Storerkey    
                  AND ReceiptKey = @c_ReceiptKey    
                  AND SKU        = @c_Sku    
                  --AND BeforeReceivedQty > 0     
            ORDER BY ReceiptLineNumber      
         END  
      END  
   END    
       
QUIT:    
    
END -- End Procedure    
  

GO