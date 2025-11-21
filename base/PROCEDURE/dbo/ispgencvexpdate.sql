SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ispGenCVExpDate                                            */
/* Creation Date: 25-August-2010                                        */
/* Copyright: IDS                                                       */
/* Written by: AQSKC                                                    */
/*                                                                      */
/* Purpose:  SOS# 182588 Ciba Vision Batch Scanning Decoding            */
/*                                                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 27-SEP-2010  AQSKC     1.1   Revised logic for barcode len 14 and    */
/*                              request to remove expirydate < today    */
/*                              validation (Kc01)                       */
/* 22-OCT-2010  AQSKC     1.2   Include Lottable04Label EXP_DATE and    */  
/*                              EXP-DATE (Kc02)                         */  
/* 25-Oct-2010  ung       1.3   Add batchno <> retailSKU validation     */
/*                              Year start from 2000 onwards (ung01)    */
/* 21-May-2014  TKLIM     1.4   Added Lottables 06-15                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenCVExpDate]
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

AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @c_Lottable02Label   NVARCHAR( 20),
      @c_Lottable03Label   NVARCHAR( 20),
      @c_Lottable04Label   NVARCHAR( 20),
      @c_Listname          NVARCHAR( 10),
      @c_Configkey         NVARCHAR( 30),
      @c_BatchCode         NVARCHAR( 18),
      @c_authority         NVARCHAR(  1),
      @c_facility          NVARCHAR(  5),
      @c_Year              NVARCHAR(  4),
      @c_Month             NVARCHAR(  2),
      @c_Day               NVARCHAR(  2),
      @n_Year              INT,
      @n_Month             INT,
      @c_Date              NVARCHAR(  6),
      @c_PreDate           NVARCHAR(  8),
      @dt_ExpDate          DATETIME,
      @n_Valid             INT, 
      @c_RetailSKU         NVARCHAR( 20)
   

   DECLARE @n_continue     INT,
           @b_debug        INT

   SET @c_ListName   = 'CVBATCH'
   SET @c_Configkey  = 'DECODEBATCH'
   SET @c_BatchCode  = ''
   SET @c_authority  = '0'
   SET @c_facility   = ''
   SET @c_Year       = ''
   SET @c_Month      = ''
   SET @c_Day        = '01'
   SET @c_PreDate    = ''
   SET @c_Date       = ''
   SET @n_Valid      = 0
   
   SELECT @n_continue = 1, @b_success = 1, @n_Err  = 0, @b_debug = 0

   SELECT @b_success = 0  
   EXECUTE dbo.nspGetRight 
      @c_facility,  -- use blank facility 
      @c_Storerkey, -- Storerkey  
      NULL,         -- Sku  
      @c_Configkey, -- Configkey  
      @b_success    output,  
      @c_authority  output,   
      @n_err        output,  
      @c_errmsg     output  
   
   
   IF @b_success <> 1  
   BEGIN  
      SELECT @n_continue = 3, @c_errmsg = 'ispGenCVExpDate' + RTrim(@c_errmsg)  
   END  
   ELSE IF @c_authority <> '1'  
   BEGIN
      SET @n_continue = 3
   END

   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN 
      SET @b_Success = 0
      SET @c_BatchCode = @c_Lottable02Value
      IF RTRIM(ISNULL(@c_BatchCode,'')) = ''
      BEGIN
         SET @n_Err = 30009
         SET @c_Errmsg = CONVERT( NVARCHAR(5), @n_Err) + 'Blank Batchcode'
         GOTO QUIT
      END
      
      SELECT 
         @c_Lottable04Label = RTRIM(SKU.Lottable04Label), 
         @c_RetailSKU = RetailSKU --(ung01)
      FROM SKU SKU WITH (NOLOCK)
      WHERE SKU.Storerkey = RTrim(@c_Storerkey)
      AND   SKU.SKU = RTrim(@c_Sku)

      IF @b_debug = 1
      BEGIN
         SELECT 'Barcode', @c_BatchCode
         SELECT 'Lottable04Label', @c_Lottable04Label
         SELECT 'RetailSKU', @c_RetailSKU
      END

      --(ung01)
      IF RTRIM(ISNULL(@c_BatchCode,'')) = ISNULL( @c_RetailSKU, '')
      BEGIN
         SET @n_Err = 30010
         SET @c_Errmsg = CONVERT( NVARCHAR(5), @n_Err) + 'ItIsRetailSKU'
         GOTO QUIT
      END

      --set to decode expiry date
      IF @c_Lottable04Label = 'CVEXPDT' OR @c_Lottable04Label = 'EXP-DATE' OR @c_Lottable04Label = 'EXP_DATE'     --(Kc02)  
      BEGIN
         SELECT @n_continue = 1
      END
      ELSE 
      BEGIN
         SET @n_continue = 3
         SET @b_Success = 1
      END         
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF LEN(@c_BatchCode) = 12 
      BEGIN
         SET @c_Date = RIGHT(@c_BatchCode, 4)
         IF ISNUMERIC(@c_Date) = 0
         BEGIN
            SET @n_Err = 30001
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + 'InvBatch. Batchcode='+ RTrim(@c_BatchCode) +' (ispGenCVExpDate)'    
            GOTO QUIT
         END
      
         SET @c_Year = '20' + RIGHT(@c_Date,2) --(ung01)
         SET @c_Month = LEFT(@c_Date,2) 
         SET @c_PreDate = @c_Year + @c_Month + @c_Day
         
         GOTO VALIDATE_DATE
      END
      ELSE IF LEN(@c_BatchCode) = 14
      BEGIN
         --(Kc01) - start
--         SET @c_Date = LEFT(@c_BatchCode,1)
--         SET @n_valid = 0
--
--         SELECT @n_valid    = COUNT(1)
--         FROM   CODELKUP CODELKUP WITH (NOLOCK)
--         WHERE  LISTNAME   = @c_Listname
--         AND    CODE       = @c_Date
--
--         IF @n_valid = 0
--         BEGIN
--            SET @c_Date = LEFT(@c_BatchCode,2)
--            SELECT @n_valid    = COUNT(1)
--            FROM   CODELKUP CODELKUP WITH (NOLOCK)
--            WHERE  LISTNAME   = @c_Listname
--            AND    CODE       = @c_Date
--         END
--
--         IF @n_Valid = 1
--         BEGIN
--            SET @c_Date = SUBSTRING(@c_BatchCode, 8, 6)
--            IF ISNUMERIC(@c_Date) = 0
--            BEGIN
--               SET @n_Err = 30002
--               SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + 'InvBatch. Batchcode='+ RTrim(@c_BatchCode) +' (ispGenCVExpDate)'    
--               GOTO QUIT
--            END
--         
--            SET @c_Year = LEFT(@c_Date,4)
--            SET @c_Month = RIGHT(@c_Date,2) 
--            SET @c_PreDate = @c_Year + @c_Month + @c_Day
--            
--            GOTO VALIDATE_DATE
--         END
--         ELSE
--         BEGIN --invalid barcode
--            SET @n_Err = 30003
--            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + 'InvFormat. Batchcode='+ RTrim(@c_BatchCode) +' (ispGenCVExpDate)'    
--            GOTO QUIT
--         END

         IF SUBSTRING(@c_BatchCode, 8, 1) = '2' AND SUBSTRING(@c_BatchCode, 9, 1) <> '2' AND ISNUMERIC(SUBSTRING(@c_BatchCode, 14, 1)) = 1
         BEGIN
            SET @c_Date = SUBSTRING(@c_BatchCode, 8, 6)
         END
         ELSE
         BEGIN
            SET @c_Date = SUBSTRING(@c_BatchCode, 9, 6)
         END

         IF ISNUMERIC(@c_Date) = 0
         BEGIN
            SET @n_Err = 30002
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + 'InvBatch. Batchcode='+ RTrim(@c_BatchCode) +' (ispGenCVExpDate)'    
            GOTO QUIT
         END
      
         SET @c_Year = LEFT(@c_Date,4)
         SET @c_Month = RIGHT(@c_Date,2) 
         SET @c_PreDate = @c_Year + @c_Month + @c_Day
         
         GOTO VALIDATE_DATE

         --(Kc01) - end
      END
      ELSE IF LEN(@c_BatchCode) = 16
      BEGIN
         SET @c_Date = SUBSTRING(@c_BatchCode, 9, 4)
         IF ISNUMERIC(@c_Date) = 0
         BEGIN
            SET @n_Err = 30004
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + 'InvBatch. Batchcode='+ RTrim(@c_BatchCode) +' (ispGenCVExpDate)'    
            GOTO QUIT
         END
      
         SET @c_Year = '20' + RIGHT(@c_Date,2) --(ung01)
         SET @c_Month = LEFT(@c_Date,2) 
         SET @c_PreDate = @c_Year + @c_Month + @c_Day
         
         GOTO VALIDATE_DATE

      END
      ELSE  --invalid barcode
      BEGIN
         SET @n_Err = 30000
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + 'InvFormat. Batchcode='+ RTrim(@c_BatchCode) +' (ispGenCVExpDate)'    
         GOTO QUIT
      END   --invalid barcode

      VALIDATE_DATE:
      IF @b_debug = 1
      BEGIN
         SELECT '@c_Month', @c_Month
         SELECT '@c_Year', @c_Year
         SELECT '@c_PreDate', @c_PreDate
      END

      SELECT @n_Year = CAST(@c_Year AS INT)
      SELECT @n_Month = CAST(@c_Month AS INT) 
      
      IF @n_Year <= 0
      BEGIN
         SET @n_Err = 30005
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Year < 0.  (ispGenCVExpDate)'  
         GOTO QUIT
      END

      IF @n_Month <= 0 OR @n_Month > 12
      BEGIN
         SET @n_Err = 30006
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Invalid Month .  (ispGenCVExpDate)'  
         GOTO QUIT
      END

      IF LEN(@c_PreDate) = 6
      BEGIN
         SET @dt_ExpDate = CONVERT( DATETIME, @c_PreDate, 12)            
      END
      ELSE
      BEGIN
         SET @dt_ExpDate = CONVERT( DATETIME, @c_PreDate, 112)
      END

      IF ISDATE(@dt_ExpDate) = 0
      BEGIN
         SET @n_Err = 30007
         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Invalid Date. Batchcode='+ RTrim(@c_BatchCode) +' (ispGenCVExpDate)'    
         GOTO QUIT
      END

      --(Kc01) - start
--      IF @dt_ExpDate < GetDate()
--      BEGIN
--         SET @n_Err = 30008
--         SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' ExpDt<SysDt. Batchcode='+ RTrim(@c_BatchCode) +' (ispGenCVExpDate)'    
--         GOTO QUIT
--      END
      --(Kc01) - end

      SET @dt_Lottable04 = @dt_ExpDate
      IF @b_debug = 1
      BEGIN
         SELECT '@dt_Lottable04', @dt_Lottable04
      END

   END --@n_continue = 1 or 2
      
   QUIT:
   SET @c_Lottable02 = @c_Lottable02Value
   IF @b_debug = 1
   BEGIN
      SELECT '@c_Errmsg', @c_Errmsg
   END

END -- End Procedure

GO