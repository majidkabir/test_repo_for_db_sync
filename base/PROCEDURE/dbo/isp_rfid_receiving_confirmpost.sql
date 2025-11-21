SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_RFID_Receiving_ConfirmPost                      */  
/* Creation Date: 2020-09-21                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: WMS-14739 - CN NIKE O2 WMS RFID Receiving Module             */
/*          ASN Header                                                   */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 09-OCT-2020 Wan      1.0   Created                                    */
/* 10-Jun-2021 WLChooi  1.1   WMS-16736 Copy UDF08&09 to new line (WL01) */
/*************************************************************************/   
CREATE PROCEDURE [dbo].[isp_RFID_Receiving_ConfirmPost] 
  @c_StorerKey       NVARCHAR(15)  
, @c_Facility        NVARCHAR(5)   
, @c_ReceiptKey      NVARCHAR(10)  
, @c_POKey           NVARCHAR(10) -- Blank = receive to ReceiptDetail with blank POKey  
, @c_ToLoc           NVARCHAR(10)  
, @c_ToID            NVARCHAR(18) -- Blank = receive to blank ToID  
, @c_SKU             NVARCHAR(20) -- SKU code. Not SKU barcode  
, @c_UOM             NVARCHAR(10)  
, @n_QTY             INT          -- In master unit  
, @c_Lottable01      NVARCHAR(18)   = ''
, @c_Lottable02      NVARCHAR(18)   = ''
, @c_Lottable03      NVARCHAR(18)   = ''
, @dt_Lottable04     DATETIME       = NULL      
, @dt_Lottable05     DATETIME       = NULL
, @c_Lottable06      NVARCHAR(30)   = ''
, @c_Lottable07      NVARCHAR(30)   = ''
, @c_Lottable08      NVARCHAR(30)   = ''
, @c_Lottable09      NVARCHAR(30)   = ''
, @c_Lottable10      NVARCHAR(30)   = ''
, @c_Lottable11      NVARCHAR(30)   = ''
, @c_Lottable12      NVARCHAR(30)   = ''
, @dt_Lottable13     DATETIME       = NULL  
, @dt_Lottable14     DATETIME       = NULL
, @dt_Lottable15     DATETIME       = NULL
, @c_UserDefine02    NVARCHAR(30)   = ''
, @c_UserDefine04    NVARCHAR(30)   = ''
, @c_ConditionCode   NVARCHAR( 10)  = 'OK'
, @c_SubreasonCode   NVARCHAR( 10)  = '' 
, @b_Success         INT            = 1   OUTPUT   
, @n_Err             INT            = 0   OUTPUT
, @c_Errmsg          NVARCHAR(255)  = ''  OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue                       INT = 1
         , @n_StartTCnt                      INT = @@TRANCOUNT

         , @n_Cnt                            INT = 0
         , @n_Debug                          INT = 0 

         , @c_DocType                        NVARCHAR(1)  = ''
         , @c_PackKey                        NVARCHAR(10)  
         , @c_PackUOM3                       NVARCHAR(10) = ''

         , @n_QtyExpected_Total              INT         = 0         
         , @n_BeforeReceivedQty_Total        INT         = 0 
         , @n_TolerancePercentage            INT         = 0

         , @n_QtyToRec                       INT         = 0    
         , @n_LineBal                        INT         = 0
         , @n_QtyExpected                    INT         = 0
         , @n_BeforeReceivedQty              INT         = 0
         , @n_BeforeReceivedQty_Org          INT         = 0

         , @n_lottable01Input                INT         = 0        
         , @n_lottable02Input                INT         = 0  
         , @n_lottable03Input                INT         = 0        
         , @n_lottable04Input                INT         = 0     
         , @n_lottable05Input                INT         = 0        
         , @n_lottable06Input                INT         = 0  
         , @n_lottable07Input                INT         = 0        
         , @n_lottable08Input                INT         = 0     
         , @n_lottable09Input                INT         = 0        
         , @n_lottable10Input                INT         = 0 
         , @n_lottable11Input                INT         = 0        
         , @n_lottable12Input                INT         = 0  
         , @n_lottable13Input                INT         = 0        
         , @n_lottable14Input                INT         = 0     
         , @n_lottable15Input                INT         = 0  

         , @c_ReceiptLineNumber              NVARCHAR(5) = '' 
         , @c_NewReceiptLineNumber           NVARCHAR(5) = ''
         , @c_AltSku                         NVARCHAR(20)= ''
         , @c_Tariffkey                      NVARCHAR(10) = '' 
         , @c_UserDefine01                   NVARCHAR(30) = ''
         , @c_UserDefine03                   NVARCHAR(30) = ''
         , @c_UserDefine05                   NVARCHAR(30) = ''
         , @dt_UserDefine06                  DATETIME 
         , @dt_UserDefine07                  DATETIME 
         , @c_UserDefine08                   NVARCHAR(30) = '' 
         , @c_UserDefine09                   NVARCHAR(30) = '' 
         , @c_UserDefine10                   NVARCHAR(30) = '' 
         
         , @c_ActionFlag                     NVARCHAR(1)  = ''

         , @c_DisAllowDuplicateIdsOnRFRcpt   NVARCHAR(30) = '0'
         , @c_Allow_OverReceipt              NVARCHAR(10) = '' 
         , @c_ByPassTolerance                NVARCHAR(10) = '' 

         , @CURRD                            CURSOR 
   SET @b_Success = 1
   SET @c_Errmsg = ''

   IF @n_Err = 999   
   BEGIN  
      SET  @n_Debug = 1    
   END

   SET @n_Err = 0            
  
   BEGIN TRAN
/*-------------------------------------------------------------------------------  
                                 Get storer config  
-------------------------------------------------------------------------------*/  
   -- Storer config var  
   IF @c_POKey = 'NOPO'  
   BEGIN  
      SET @c_POKey = ''  
   END  
  
   -- NSQLConfig 'DisAllowDuplicateIdsOnRFRcpt'  
   SET @c_DisAllowDuplicateIdsOnRFRcpt = 0 -- Default Off  
   SELECT @c_DisAllowDuplicateIdsOnRFRcpt = NSQLValue  
   FROM dbo.NSQLConfig (NOLOCK)  
   WHERE ConfigKey = 'DisAllowDuplicateIdsOnRFRcpt'  

   -- Truncate the time portion  
   IF @dt_Lottable04 IS NOT NULL  
      SET @dt_Lottable04 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dt_Lottable04, 120), 120)  
   IF @dt_Lottable05 IS NOT NULL  
      SET @dt_Lottable05 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dt_Lottable05, 120), 120)  
   IF @dt_Lottable13 IS NOT NULL  
      SET @dt_Lottable13 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dt_Lottable13, 120), 120)  
   IF @dt_Lottable14 IS NOT NULL  
      SET @dt_Lottable14 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dt_Lottable14, 120), 120)  
   IF @dt_Lottable15 IS NOT NULL  
      SET @dt_Lottable15 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dt_Lottable15, 120), 120)  
  
   /*-------------------------------------------------------------------------------  
                                    Validate data  
   -------------------------------------------------------------------------------*/  

   -- Validate ToID  
   IF @c_DisAllowDuplicateIdsOnRFRcpt = '1' AND @c_ToID <> ''  
   BEGIN  
      IF EXISTS(  SELECT 1  
                  FROM dbo.LOTxLOCxID LLI (NOLOCK)  
                  INNER JOIN dbo.LOC LOC (NOLOCK) ON (LLI.LOC = LOC.LOC)  
                  WHERE LLI.ID = @c_ToID  
                  AND LLI.QTY > 0  
                  AND LOC.Facility = @c_Facility
               ) -- Check duplicate ID within same facility only  
      BEGIN  
         SET @n_Continue = 3
         SET @n_Err      = 87010
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': ID Is In Used.'
                         + ' (isp_RFID_Receiving_ConfirmPost)'
         GOTO QUIT_SP
      END  
   END  

   SELECT @c_AltSku  =  ISNULL(SKU.ALTSKU,'')
         ,@c_PackKey =  SKU.PackKey 
         ,@c_Tariffkey= SKU.Tariffkey  
         ,@n_TolerancePercentage = CASE WHEN SKU.SUSR4 IS NOT NULL AND ISNUMERIC(SKU.SUSR4) = 1  
                                        THEN CAST(SKU.SUSR4 AS INT)  
                                        ELSE 0  
                                   END  
         , @n_lottable01Input = CASE WHEN ISNULL(SKU.Lottable01Label,'') <> '' THEN 1 ELSE 0 END       
         , @n_lottable02Input = CASE WHEN ISNULL(SKU.Lottable02Label,'') <> '' THEN 1 ELSE 0 END 
         , @n_lottable03Input = CASE WHEN ISNULL(SKU.Lottable03Label,'') <> '' THEN 1 ELSE 0 END       
         , @n_lottable04Input = CASE WHEN ISNULL(SKU.Lottable04Label,'') <> '' THEN 1 ELSE 0 END    
         , @n_lottable05Input = CASE WHEN ISNULL(SKU.Lottable05Label,'') <> '' THEN 1 ELSE 0 END       
         , @n_lottable06Input = CASE WHEN ISNULL(SKU.Lottable06Label,'') <> '' THEN 1 ELSE 0 END 
         , @n_lottable07Input = CASE WHEN ISNULL(SKU.Lottable07Label,'') <> '' THEN 1 ELSE 0 END       
         , @n_lottable08Input = CASE WHEN ISNULL(SKU.Lottable08Label,'') <> '' THEN 1 ELSE 0 END    
         , @n_lottable09Input = CASE WHEN ISNULL(SKU.Lottable09Label,'') <> '' THEN 1 ELSE 0 END       
         , @n_lottable10Input = CASE WHEN ISNULL(SKU.Lottable10Label,'') <> '' THEN 1 ELSE 0 END
         , @n_lottable11Input = CASE WHEN ISNULL(SKU.Lottable11Label,'') <> '' THEN 1 ELSE 0 END       
         , @n_lottable12Input = CASE WHEN ISNULL(SKU.Lottable12Label,'') <> '' THEN 1 ELSE 0 END 
         , @n_lottable13Input = CASE WHEN ISNULL(SKU.Lottable13Label,'') <> '' THEN 1 ELSE 0 END       
         , @n_lottable14Input = CASE WHEN ISNULL(SKU.Lottable14Label,'') <> '' THEN 1 ELSE 0 END    
         , @n_lottable15Input = CASE WHEN ISNULL(SKU.Lottable15Label,'') <> '' THEN 1 ELSE 0 END                                    
   FROM dbo.SKU SKU (NOLOCK)  
   WHERE StorerKey = @c_StorerKey  
   AND SKU = @c_SKU  

   SELECT @c_PackUOM3 = PackUOM3   
   FROM PACK WITH (NOLOCK)   
   WHERE PackKey = @c_PackKey  
     
   -- Validate UOM field  
   IF @c_UOM = ''  
   BEGIN  
      SET @c_UOM = @c_PackUOM3  
   END  

   -- Validate UOM exists  
   IF NOT EXISTS( SELECT 1  
                  FROM dbo.Pack P (NOLOCK)  
                  INNER JOIN dbo.SKU S (NOLOCK) ON P.PackKey = S.PackKey  
                  WHERE S.StorerKey = @c_StorerKey  
                  AND S.SKU = @c_SKU  
                  AND @c_UOM IN (  
                                 P.PackUOM1, P.PackUOM2, P.PackUOM3, P.PackUOM4,  
                                 P.PackUOM5, P.PackUOM6, P.PackUOM7, P.PackUOM8, P.PackUOM9
                                 )
                )  
   BEGIN  
      SET @n_Continue = 3
      SET @n_Err      = 87020
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Invalid UOM.'
                        + ' (isp_RFID_Receiving_ConfirmPost)'
      GOTO QUIT_SP
   END  
 
/*-------------------------------------------------------------------------------  
                            StorerConfig Setup  
-------------------------------------------------------------------------------*/  
   SELECT @c_Allow_OverReceipt= dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'Allow_OverReceipt')
   SELECT @c_ByPassTolerance  = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ByPassTolerance')
  
/*-------------------------------------------------------------------------------  
                            ReceiptDetail lookup logic  
-------------------------------------------------------------------------------*/  
/*  
   Steps:  
   0. Check over receive  
   1. Find exact match line  
   2. If have bal, find blank line  
   3. If have bal, add line  
      3.1 borrow from other line, receive it  
  
   NOTES: Should receive ALL UCC first before loose QTY  
*/  
 
   -- ReceiptDetail candidate  
   DECLARE @tRD TABLE  
   (     ReceiptKey              NVARCHAR(10)   DEFAULT('')
      ,  ReceiptLineNumber       NVARCHAR(5)    DEFAULT('')
      ,  POKey                   NVARCHAR(10)   DEFAULT('') 
      ,  QtyExpected             INT            DEFAULT(0)
      ,  BeforeReceivedQty       INT            DEFAULT(0)
      ,  ToLoc                   NVARCHAR(10)   DEFAULT('')
      ,  ToID                    NVARCHAR(18)   DEFAULT('')
      ,  Lottable01              NVARCHAR(18)   DEFAULT('')
      ,  Lottable02              NVARCHAR(18)   DEFAULT('')
      ,  Lottable03              NVARCHAR(18)   DEFAULT('')
      ,  Lottable04              DATETIME       
      ,  Lottable06              NVARCHAR(30)   DEFAULT('')    
      ,  Lottable07              NVARCHAR(30)   DEFAULT('')    
      ,  Lottable08              NVARCHAR(30)   DEFAULT('')    
      ,  Lottable09              NVARCHAR(30)   DEFAULT('')    
      ,  Lottable10              NVARCHAR(30)   DEFAULT('')    
      ,  Lottable11              NVARCHAR(30)   DEFAULT('')    
      ,  Lottable12              NVARCHAR(30)   DEFAULT('')    
      ,  Lottable13              DATETIME          
      ,  Lottable14              DATETIME          
      ,  Lottable15              DATETIME          
      ,  UserDefine01            NVARCHAR(30)   DEFAULT('')   
      ,  UserDefine02            NVARCHAR(30)   DEFAULT('') 
      ,  UserDefine03            NVARCHAR(30)   DEFAULT('') 
      ,  UserDefine04            NVARCHAR(30)   DEFAULT('') 
      ,  UserDefine05            NVARCHAR(30)   DEFAULT('') 
      ,  UserDefine06            DATETIME 
      ,  UserDefine07            DATETIME 
      ,  UserDefine08            NVARCHAR(30)   DEFAULT('')     
      ,  UserDefine09            NVARCHAR(30)   DEFAULT('')  
      ,  UserDefine10            NVARCHAR(30)   DEFAULT('')  
      ,  ReceiptLineNumber_Org   NVARCHAR(5) -- Keeping original value, use in saving section 
      ,  BeforeReceivedQty_Org   INT            DEFAULT(0)
      ,  FinalizeFlag            NVARCHAR(1)    DEFAULT('N') 
      ,  EditDate                DATETIME       
      ,  ActionFlag              CHAR(1)        DEFAULT('')
   )  
  
 -- Copy QTY to process  
   SET @n_QtyToRec = @n_Qty  
  
   -- Get ReceiptDetail candidate  
   INSERT INTO @tRD 
      (  Receiptkey, ReceiptLineNumber, POKey
      ,  ToLoc, ToID, QtyExpected, BeforeReceivedQty
      ,  Lottable01, Lottable02, Lottable03, Lottable04 
      ,  Lottable06, Lottable07, Lottable08, Lottable09, Lottable10
      ,  Lottable11, Lottable12, Lottable13, Lottable14, Lottable15                                                                                   
      ,  UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05  
      ,  UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10
      ,  FinalizeFlag, ReceiptLineNumber_Org, BeforeReceivedQty_Org, EditDate
      )
   SELECT Receiptkey, ReceiptLineNumber, POKey
      ,   ToLoc, ToID, QtyExpected, BeforeReceivedQty  
      ,   Lottable01, Lottable02, Lottable03, Lottable04 
      ,   Lottable06, Lottable07, Lottable08, Lottable09, Lottable10
      ,   Lottable11, Lottable12, Lottable13, Lottable14, Lottable15                                                                                   
      ,   UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05  
      ,   UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10
      ,   FinalizeFlag, ReceiptLineNumber, BeforeReceivedQty, GetDate()   
   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)  
   WHERE ReceiptKey= @c_ReceiptKey   
   AND   StorerKey = @c_StorerKey   
   AND   SKU       = @c_SKU  
    
   SELECT TOP 1 @n_Cnt = 1
   FROM @tRD  
  
   -- Get total QtyExpected, BeforeReceivedQty  
   SELECT  
      @n_QtyExpected_Total = ISNULL(SUM( QtyExpected), 0),  
      @n_BeforeReceivedQty_Total = ISNULL(SUM( BeforeReceivedQty), 0)  
   FROM @tRD   
  
   --Check if over receive  
   IF (@n_QtyToRec + @n_BeforeReceivedQty_Total) > @n_QtyExpected_Total  
   BEGIN  
      IF @c_Allow_OverReceipt = '0'  
      BEGIN  
         SET @n_Continue = 3
         SET @n_Err      = 87030
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Over Received.'
                           + ' (isp_RFID_Receiving_ConfirmPost)'
         GOTO QUIT_SP 
      END  
      ELSE  
      -- Check if bypass tolerance  
      IF @c_ByPassTolerance <> '1' 
      BEGIN 
         -- Check if over tolerance %  
         IF (@n_QtyToRec + @n_BeforeReceivedQty_Total) > (@n_QtyExpected_Total * (1 + (@n_TolerancePercentage * 0.01)))  
         BEGIN  
            SET @n_Continue = 3
            SET @n_Err      = 87040
            SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': QtyReceived Over Tolerance%.'
                              + ' (isp_RFID_Receiving_ConfirmPost)'
            GOTO QUIT_SP 
         END  
      END 
   END  
  
 
   IF @n_Debug = 1  
   BEGIN  
      SELECT  @n_QtyToRec 'STEP 1 @n_QtyToRec' ,@n_Qty '@n_Qty'  
   END  
  
   Steps:  
   -- Steps  
   -- 1. Find exact match lines (could be more then 1 line)  
   --    1.1 Receive up to QtyExpected  
   SET @c_ReceiptLineNumber = ''  
   WHILE 1=1  
   BEGIN  
      -- Get exact match line  
      SELECT TOP 1  
           @c_ReceiptLineNumber = ReceiptLineNumber
         , @n_LineBal = (QtyExpected - BeforeReceivedQty) 
      FROM @tRD  
      WHERE FinalizeFlag <> 'Y'  
         AND ToLoc= @c_ToLoc    
         AND ToID = @c_ToID  
         AND Lottable01 = @c_Lottable01  
         AND Lottable02 = @c_Lottable02  
         AND Lottable03 = @c_Lottable03  
         AND Lottable04 = @dt_Lottable04  
         AND Lottable06 = @c_Lottable06                         
         AND Lottable07 = @c_Lottable07                         
         AND Lottable08 = @c_Lottable08                         
         AND Lottable09 = @c_Lottable09                         
         AND Lottable10 = @c_Lottable10                         
         AND Lottable11 = @c_Lottable11                         
         AND Lottable12 = @c_Lottable12                         
         AND Lottable13 = @dt_Lottable13
         AND Lottable14 = @dt_Lottable14
         AND Lottable15 = @dt_Lottable15
         AND UserDefine02 = @c_UserDefine02
         AND UserDefine04 = @c_UserDefine04
         AND QtyExpected - BeforeReceivedQty > 0   
         AND ReceiptLineNumber > @c_ReceiptLineNumber   
      ORDER BY ReceiptLineNumber  
  
      -- Exit loop  
      IF @@ROWCOUNT = 0 BREAK  
        
      IF @n_LineBal < 1 CONTINUE  
  
      -- Calc QTY to receive  
      IF @n_QtyToRec >= @n_LineBal  
         SET @n_Qty = @n_LineBal  
      ELSE  
         SET @n_Qty = @n_QtyToRec  
  
      -- Update ReceiptDetail  
 
      UPDATE @tRD SET  
            BeforeReceivedQty = BeforeReceivedQty + @n_Qty 
         ,  ActionFlag = 'U' 
      WHERE ReceiptLineNumber = @c_ReceiptLineNumber  
  
      -- Reduce balance  
      SET @n_QtyToRec = @n_QtyToRec - @n_Qty  
      -- Exit loop  
      IF @n_Debug = 1
      BEGIN  
         SELECT  @n_QtyToRec 'STEP 1.1 @n_QtyToRec After' , @n_Qty '@n_Qty'  
      END  
  
      IF @n_QtyToRec = 0 BREAK  
   END  
  
   IF @n_Debug = 1
   BEGIN  
      SELECT  @n_QtyToRec 'STEP 2 @n_QtyToRec' , @c_ReceiptLineNumber '@c_ReceiptLineNumber'
   END  
  
   SET @c_ReceiptLineNumber = ''  
   WHILE @n_QtyToRec > 0  
   BEGIN  
      -- Get blank line  
      SELECT TOP 1  
            @c_ReceiptLineNumber = ReceiptLineNumber  
         ,  @n_LineBal = (QtyExpected - BeforeReceivedQty) 
      FROM @tRD  
      WHERE FinalizeFlag <> 'Y'  
         AND ToID = ''
         AND ToLoc = '' 
         AND 
            (Lottable01 = '' AND  
             Lottable02 = '' AND  
             Lottable03 = '' AND  
             Lottable04 IN ('1900-01-01', NULL) AND  
             Lottable06 = '' AND  
             Lottable07 = '' AND  
             Lottable08 = '' AND  
             Lottable09 = '' AND  
             Lottable10 = '' AND  
             Lottable11 = '' AND   
             Lottable12 = '' AND   
             Lottable13 IN ('1900-01-01', NULL)  AND  
             Lottable14 IN ('1900-01-01', NULL)  AND  
             Lottable15 IN ('1900-01-01', NULL) 
           )
         AND ReceiptLineNumber > @c_ReceiptLineNumber  
      ORDER BY ReceiptLineNumber  
  
      -- Exit loop  
      IF @@ROWCOUNT = 0 BREAK  
   
      -- Calc QTY to receive  
      IF @n_QtyToRec >= @n_LineBal  
         SET @n_Qty = @n_LineBal  
      ELSE  
         SET @n_Qty = @n_QtyToRec  
  
      IF @n_Qty > 0  
      BEGIN  
         -- Update ReceiptDetail  
         UPDATE @tRD SET  
               BeforeReceivedQty = BeforeReceivedQty + @n_Qty  
            ,  ToLoc = @c_ToLoc  
            ,  ToID  = @c_ToID 
            ,  Lottable01 = @c_Lottable01 
            ,  Lottable02 = @c_Lottable02 
            ,  Lottable03 = @c_Lottable03 
            ,  Lottable04 = @dt_Lottable04  
            ,  Lottable06 = @c_Lottable06     
            ,  Lottable07 = @c_Lottable07     
            ,  Lottable08 = @c_Lottable08     
            ,  Lottable09 = @c_Lottable09     
            ,  Lottable10 = @c_Lottable10     
            ,  Lottable11 = @c_Lottable11     
            ,  Lottable12 = @c_Lottable12     
            ,  Lottable13 = @dt_Lottable13      
            ,  Lottable14 = @dt_Lottable14      
            ,  Lottable15 = @dt_Lottable15
            ,  UserDefine02 = @c_UserDefine02 
            ,  UserDefine04 = @c_UserDefine04 
            ,  ActionFlag = 'U'        
          WHERE ReceiptLineNumber = @c_ReceiptLineNumber  
  
         -- Reduce balance  
         SET @n_QtyToRec = @n_QtyToRec - @n_Qty  
      END  
      -- Exit loop  
      IF @n_QtyToRec = 0 BREAK  
   END  
  
   IF @n_Debug = 1 
   BEGIN  
      SELECT  @n_QtyToRec 'STEP 3 @n_QtyToRec - Borrow Any' ,  @c_ReceiptLineNumber '@c_ReceiptLineNumber' 
   END  
  
   --SET @n_BeforeReceivedQty = @n_QtyToRec  
   SET @c_NewReceiptLineNumber = ''   
   IF @n_QtyToRec > 0  
   BEGIN  
      -- Loop all ReceiptDetail to borrow QtyExpected  
      SET @c_ReceiptLineNumber = ''  
      WHILE 1=1  
      BEGIN  
         -- Get lines that has balance  
         SELECT TOP 1  
               @c_ReceiptLineNumber = ReceiptLineNumber 
            ,  @n_LineBal = (QtyExpected - BeforeReceivedQty) 
            ,  @c_Userdefine08 = UserDefine08   --WL01 
            ,  @c_Userdefine09 = UserDefine09   --WL01 
         FROM @tRD  
         WHERE (QtyExpected - BeforeReceivedQty) > 0  
         AND ReceiptLineNumber > @c_ReceiptLineNumber  
         ORDER BY ReceiptLineNumber  
  
         -- Exit loop  
         IF @@ROWCOUNT = 0 BREAK  
        
         -- Calc QTY to receive  
         IF @n_QtyToRec >= @n_LineBal  
            SET @n_Qty = @n_LineBal  
         ELSE  
            SET @n_Qty = @n_QtyToRec  
  
         IF @n_Debug = 1  
         BEGIN  
            SELECT @c_ReceiptLineNumber '@c_ReceiptLineNumber' , @n_LineBal '@n_LineBal' , @n_Qty '@n_Qty' , @n_QtyToRec '@n_QtyToRec'  
         END  
  
         IF @n_Qty > 0 
         BEGIN
            -- Reduce borrowed ReceiptDetail QtyExpected  
            UPDATE @tRD SET  
               QtyExpected= QtyExpected - @n_Qty
              ,ActionFlag = CASE WHEN ActionFlag = '' THEN 'U' ELSE ActionFlag END 
            WHERE ReceiptLineNumber = @c_ReceiptLineNumber  
  
            -- Reduce balance  
            SET @n_QtyToRec = @n_QtyToRec - @n_Qty  
  
            -- Revised Logic Start --  
            -- Get Temp next ReceiptLineNumber  
            SELECT @c_NewReceiptLineNumber =  
               RIGHT( '00000' + CAST( CAST( IsNULL( MAX( ReceiptLineNumber), 0) AS INT) + 1 AS VARCHAR( 5)), 5)  
            FROM @tRD --WITH (NOLOCK)   
  
         -- Balance insert as new ReceiptDetail line  
 
            INSERT INTO @tRD  
               (  ReceiptKey, ReceiptLineNumber, POKey
               ,  QtyExpected, BeforeReceivedQty, ToLoc, ToID 
               ,  Lottable01, Lottable02, Lottable03, Lottable04
               ,  Lottable06, Lottable07, Lottable08, Lottable09, Lottable10       
               ,  Lottable11, Lottable12, Lottable13 ,Lottable14, Lottable15                               
               ,  UserDefine01, UserDefine02, UserDefine04
               ,  ReceiptLineNumber_Org, ActionFlag, EditDate
               ,  UserDefine08, UserDefine09 )   --WL01 
            SELECT   
               @c_Receiptkey, @c_NewReceiptLineNumber, @c_POKey
            ,  @n_Qty, @n_Qty , @c_ToLoc, @c_ToID
            ,  Lottable01 = CASE WHEN @n_Lottable01Input  = 1 THEN @c_Lottable01  ELSE Lottable01 END
            ,  Lottable02 = CASE WHEN @n_Lottable02Input  = 1 THEN @c_Lottable02  ELSE Lottable02 END
            ,  Lottable03 = CASE WHEN @n_Lottable03Input  = 1 THEN @c_Lottable03  ELSE Lottable03 END
            ,  Lottable04 = CASE WHEN @n_Lottable04Input  = 1 THEN @dt_Lottable04 ELSE Lottable04 END
            ,  Lottable06 = CASE WHEN @n_Lottable06Input  = 1 THEN @c_Lottable06  ELSE Lottable06 END
            ,  Lottable07 = CASE WHEN @n_Lottable07Input  = 1 THEN @c_Lottable07  ELSE Lottable07 END
            ,  Lottable08 = CASE WHEN @n_Lottable08Input  = 1 THEN @c_Lottable08  ELSE Lottable08 END
            ,  Lottable09 = CASE WHEN @n_Lottable09Input  = 1 THEN @c_Lottable09  ELSE Lottable09 END
            ,  Lottable10 = CASE WHEN @n_Lottable10Input  = 1 THEN @c_Lottable10  ELSE Lottable10 END
            ,  Lottable11 = CASE WHEN @n_Lottable11Input  = 1 THEN @c_Lottable11  ELSE Lottable11 END
            ,  Lottable12 = CASE WHEN @n_Lottable12Input  = 1 THEN @c_Lottable12  ELSE Lottable12 END
            ,  Lottable13 = CASE WHEN @n_Lottable13Input  = 1 THEN @dt_Lottable13 ELSE Lottable13 END
            ,  Lottable14 = CASE WHEN @n_Lottable14Input  = 1 THEN @dt_Lottable14 ELSE Lottable14 END
            ,  Lottable15 = CASE WHEN @n_Lottable15Input  = 1 THEN @dt_Lottable15 ELSE Lottable15 END  
            ,  @c_UserDefine01, @c_UserDefine02, @c_UserDefine04  
            ,  @c_ReceiptLineNumber, 'I', GetDate() 
            ,  @c_Userdefine08, @c_Userdefine09   --WL01 
            FROM @tRD AS tr
            WHERE  ReceiptLineNumber =  @c_ReceiptLineNumber 
         END
      END
   END 

   IF @n_QtyToRec > 0
   BEGIN
      SET @n_Qty = @n_QtyToRec

      SELECT @c_NewReceiptLineNumber =  
         RIGHT( '00000' + CAST( CAST( IsNULL( MAX( ReceiptLineNumber), 0) AS INT) + 1 AS VARCHAR( 5)), 5)  
      FROM @tRD --WITH (NOLOCK)   
  
      -- Balance insert as new ReceiptDetail line  
 
      INSERT INTO @tRD  
         (  ReceiptKey, ReceiptLineNumber, POKey
         ,  QtyExpected, BeforeReceivedQty, ToLoc, ToID
         ,  Lottable01, Lottable02, Lottable03, Lottable04
         ,  Lottable06, Lottable07, Lottable08, Lottable09, Lottable10       
         ,  Lottable11, Lottable12, Lottable13 ,Lottable14, Lottable15                               
         ,  UserDefine01, UserDefine02, UserDefine04
         ,  ReceiptLineNumber_Org, ActionFlag, EditDate
         ,  UserDefine08, UserDefine09 )   --WL01   
      VALUES  
      (  @c_Receiptkey, @c_NewReceiptLineNumber, @c_POKey
      ,  @n_Qty, @n_Qty , @c_ToLoc, @c_ToID
      ,  @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04  
      ,  @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09,  @c_Lottable10  
      ,  @c_Lottable11 ,@c_Lottable12, @dt_Lottable13,@dt_Lottable14, @dt_Lottable15 
      ,  @c_UserDefine01, @c_UserDefine02, @c_UserDefine04 
      ,  '', 'I', GetDate() 
      ,  @c_Userdefine08, @c_Userdefine09   --WL01 
         )    
   END   
    
   -- If still have balance, means offset has error  
   IF @n_QtyToRec <> 0  
   BEGIN  
      SET @n_Continue = 3
      SET @n_Err      = 87050
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Offset Receipt Detail Error.'
                        + ' (isp_RFID_Receiving_ConfirmPost)'
      GOTO QUIT_SP 
   END  
  
/*-------------------------------------------------------------------------------  
  
                              Write to ReceiptDetail  
  
-------------------------------------------------------------------------------*/  
   SET @CURRD = CURSOR FOR  
      SELECT  
           ReceiptLineNumber
         , QtyExpected 
         , BeforeReceivedQty
         , BeforeReceivedQty_Org 
         , ActionFlag
      FROM @tRD  
      WHERE ActionFlag IN ('I', 'U')
      ORDER BY ReceiptLineNumber
    
   OPEN @CURRD  

   FETCH NEXT FROM @CURRD INTO @c_ReceiptLineNumber
                              ,@n_QtyExpected 
                              ,@n_BeforeReceivedQty 
                              ,@n_BeforeReceivedQty_Org
                              ,@c_ActionFlag 
  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      IF @c_ActionFlag = 'I'
      BEGIN
         SET @c_NewReceiptLineNumber = ''  
         SELECT TOP 1 @c_NewReceiptLineNumber = RIGHT( '00000' + CAST( (CAST( ReceiptLineNumber AS INT) + 1) AS VARCHAR( 5)), 5)  
         FROM dbo.ReceiptDetail (NOLOCK)  
         WHERE ReceiptKey = @c_ReceiptKey
         ORDER BY ReceiptLineNumber DESC 
  
         INSERT INTO dbo.ReceiptDetail  
         (  ReceiptKey, ReceiptLineNumber, StorerKey, SKU, AltSku, UOM, PackKey, TariffKey  
         ,  ToLoc, ToID, QtyExpected, BeforeReceivedQty
         ,  Lottable01, Lottable02, Lottable03, Lottable04   
         ,  Lottable06, Lottable07, Lottable08, Lottable09, Lottable10      
         ,  Lottable11, Lottable12, Lottable13, Lottable14, Lottable15  
         ,  UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05  
         ,  UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10   
         ,  [Status], FinalizeFlag, SubReasonCode, ConditionCode, POKey
         ,  ExternReceiptKey, ExternLineNo, POLineNumber
         ,  ExternPoKey, LoadKey
         ,  VesselKey, VoyageKey, ContainerKey, XdockKey
         ,  UnitPrice, ExtendedPrice, FreeGoodQtyExpected, FreeGoodQtyReceived
         ,  EffectiveDate, DateReceived
         ,  ExportStatus, SplitPalletFlag,  DuplicateFrom
         ) 
         SELECT 
            T.ReceiptKey, @c_NewReceiptLineNumber, @c_StorerKey, @c_SKU, @c_AltSku, @c_UOM, @c_PackKey, @c_TariffKey
         ,  T.ToLOC, T.ToID, T.QtyExpected, T.BeforeReceivedQty
         ,  T.Lottable01, T.Lottable02, T.Lottable03, T.Lottable04   
         ,  T.Lottable06, T.Lottable07, T.Lottable08, T.Lottable09, T.Lottable10      
         ,  T.Lottable11, T.Lottable12, T.Lottable13 ,T.Lottable14, T.Lottable15    
         ,  T.UserDefine01, T.UserDefine02, T.UserDefine03, T.UserDefine04, T.UserDefine05  
         ,  T.UserDefine06, T.UserDefine07, T.UserDefine08, T.UserDefine09, T.UserDefine10                         
         ,  '0', 'N', @c_SubReasonCode, @c_ConditionCode, T.POKey
         ,  ISNULL(RD.ExternReceiptKey,''), ISNULL(RD.ExternLineNo,''), ISNULL(RD.POLineNumber,'')
         ,  ISNULL(RD.ExternPoKey,''), ISNULL(RD.LoadKey,'') 
         ,  ISNULL(RD.VesselKey,''), ISNULL(RD.VoyageKey,''), ISNULL(RD.ContainerKey,''), ISNULL(RD.XdockKey,'')
         ,  ISNULL(RD.UnitPrice,0) , ISNULL(RD.ExtendedPrice,0), ISNULL(RD.FreeGoodQtyExpected,0), ISNULL(RD.FreeGoodQtyReceived,0)
         ,  ISNULL(RD.EffectiveDate, GETDATE()), ISNULL(RD.DateReceived, GETDATE())
         ,  ISNULL(RD.ExportStatus,'0'), ISNULL(RD.SplitPalletFlag,'N'), ISNULL(T.ReceiptLineNumber_Org,'')
         FROM @tRD T 
         LEFT OUTER JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON  T.Receiptkey = RD.Receiptkey
                                                        AND T.ReceiptLineNumber_Org = RD.ReceiptLineNumber
         WHERE T.ReceiptLineNumber = @c_ReceiptLineNumber

         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Continue = 3
            SET @n_Err      = 87060
            SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Insert ReceiptDetail Fail.'
                              + ' (isp_RFID_Receiving_ConfirmPost)'
            GOTO QUIT_SP 
         END  
      END

      IF @c_ActionFlag = 'U'
      BEGIN
         -- Update ReceiptDetail  
         IF @n_BeforeReceivedQty_Org = @n_BeforeReceivedQty
         BEGIN
         	UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET  
              QtyExpected       = @n_QtyExpected  
            , BeforeReceivedQty = @n_BeforeReceivedQty 
            WHERE ReceiptKey  = @c_ReceiptKey  
            AND ReceiptLineNumber = @c_ReceiptLineNumber
         END
         ELSE
         BEGIN
            UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET  
                 QtyExpected       = @n_QtyExpected  
               , BeforeReceivedQty = @n_BeforeReceivedQty 
               , ToLOC        = @c_ToLoc 
               , ToID         = @c_ToID 
               , Lottable01   = CASE WHEN @n_Lottable01Input = 1 THEN @c_Lottable01  ELSE Lottable01 END  
               , Lottable02   = CASE WHEN @n_Lottable02Input = 1 THEN @c_Lottable02  ELSE Lottable02 END
               , Lottable03   = CASE WHEN @n_Lottable03Input = 1 THEN @c_Lottable03  ELSE Lottable03 END
               , Lottable04   = CASE WHEN @n_Lottable04Input = 1 THEN @dt_Lottable04 ELSE Lottable04 END
               , Lottable06   = CASE WHEN @n_Lottable06Input = 1 THEN @c_Lottable06  ELSE Lottable06 END
               , Lottable07   = CASE WHEN @n_Lottable07Input = 1 THEN @c_Lottable07  ELSE Lottable07 END
               , Lottable08   = CASE WHEN @n_Lottable08Input = 1 THEN @c_Lottable08  ELSE Lottable08 END
               , Lottable09   = CASE WHEN @n_Lottable09Input = 1 THEN @c_Lottable09  ELSE Lottable09 END
               , Lottable10   = CASE WHEN @n_Lottable10Input = 1 THEN @c_Lottable10  ELSE Lottable10 END
               , Lottable11   = CASE WHEN @n_Lottable11Input = 1 THEN @c_Lottable11  ELSE Lottable11 END
               , Lottable12   = CASE WHEN @n_Lottable12Input = 1 THEN @c_Lottable12  ELSE Lottable12 END
               , Lottable13   = CASE WHEN @n_Lottable13Input = 1 THEN @dt_Lottable13 ELSE Lottable13 END 
               , Lottable14   = CASE WHEN @n_Lottable14Input = 1 THEN @dt_Lottable14 ELSE Lottable14 END
               , Lottable15   = CASE WHEN @n_Lottable15Input = 1 THEN @dt_Lottable15 ELSE Lottable15 END 
               , ConditionCode= @c_ConditionCode  
               , SubreasonCode= @c_SubreasonCode   
               , UserDefine01 = @c_UserDefine01
               , UserDefine02 = @c_UserDefine02  
               , UserDefine04 = @c_UserDefine04   
            WHERE ReceiptKey  = @c_ReceiptKey  
            AND ReceiptLineNumber = @c_ReceiptLineNumber  
         END
         
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Continue = 3
            SET @n_Err      = 87070
            SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Update ReceiptDetail Fail.'
                              + ' (isp_RFID_Receiving_ConfirmPost)'
            GOTO QUIT_SP 
         END  
      END
  
      FETCH NEXT FROM @CURRD INTO @c_ReceiptLineNumber
                                 ,@n_QtyExpected 
                                 ,@n_BeforeReceivedQty
                                 ,@n_BeforeReceivedQty_Org          
                                 ,@c_ActionFlag   
   END  

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RFID_Receiving_ConfirmPost'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   REVERT      
END  

GO