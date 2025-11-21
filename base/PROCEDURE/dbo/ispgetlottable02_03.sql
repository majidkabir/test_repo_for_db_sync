SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ispGetLottable02_03                                        */
/* Creation Date: 11-Oct-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: ChewKP                                                   */
/*                                                                      */
/* Purpose: SOS#254690 Get Lottable02 value                             */
/*                                                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* 21-May-2014  TKLIM     1.1   Added Lottables 06-15                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGetLottable02_03]
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
   , @c_Sourcekey          NVARCHAR(15)   = ''     -- FromLoc
   , @c_Sourcetype         NVARCHAR(20)   = ''     -- RDTCCOUNT
   , @c_LottableLabel      NVARCHAR(20)   = '' 

AS
BEGIN
   
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @c_sValue            NVARCHAR( 1)


   DECLARE @n_continue      INT,
           @b_debug         INT,
           @n_LottableCount INT,
           @n_Count         INT,
           @c_Lot           NVARCHAR(10),
           @c_Loc           NVARCHAR(10)

   SELECT @n_continue = 1, @b_success = 1, @n_Err = 0, @b_debug = 0
             
   IF @c_Sourcetype = 'RDTCCOUNT'
   BEGIN
      IF @n_continue = 1 OR @n_continue = 2 
      BEGIN 
         SELECT @c_Lottable01  = '',
                @c_Lottable02  = '',
                @c_Lottable03  = '',
                @dt_Lottable04 = NULL,
                @dt_Lottable05 = NULL,
                @c_Lottable06 = '',
                @c_Lottable07 = '',
                @c_Lottable08 = '',
                @c_Lottable09 = '',
                @c_Lottable10 = '',
                @c_Lottable11 = '',
                @c_Lottable12 = '',
                @dt_Lottable13 = NULL,
                @dt_Lottable14 = NULL,
                @dt_Lottable15 = NULL

         SET @n_Count = 0
         SET @c_Lot = ''
         
         IF EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE Listname = 'LOTTABLE02'
                    AND Code = RTRIM(@c_LottableLabel))
         BEGIN
            SET @c_Loc = ''
            SELECT @c_Loc = V_LOC 
            FROM rdt.rdtMobRec WITH (NOLOCK) 
            WHERE UserName = sUser_sName()
            
            SET @c_Lot = ''
            -- If FromLoc have Inventory get Lottable02-03 from FromLoc Lot Lottable
            SELECT TOP 1 @c_Lot = LLI.LOT --@c_Lottable02 = LA.Lottable02, 
            FROM dbo.LotAttribute LA WITH (NOLOCK)
            INNER JOIN dbo.LotxLocxID LLI WITH (NOLOCK) ON (LLI.Lot = LA.Lot AND LLI.SKU = LA.SKU AND LLI.StorerKey = LA.StorerKey)
            WHERE LLI.Loc     = @c_Loc
            AND LLI.SKU       = @c_SKU
            AND LLI.StorerKey = @c_StorerKey 

            IF @c_Lot <> ''
            BEGIN
               GOTO Retrieve_Lottables
            END
            ELSE
            BEGIN
               -- If FromLoc do not have inventory get Lottable02 from any location in the warehouse for the same SKU with inventory
               SELECT TOP 1 @c_Lot = LLI.LOT
               FROM dbo.LotAttribute LA WITH (NOLOCK)
               INNER JOIN dbo.LotxLocxID LLI WITH (NOLOCK) ON (LLI.Lot = LA.Lot AND LLI.SKU = LA.SKU AND LLI.StorerKey = LA.StorerKey)
               WHERE LLI.SKU       = @c_SKU
                 AND LLI.StorerKey = @c_StorerKey 
                 AND LLI.Loc       <> @c_Loc
                 AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - LLI.QtyReplen) > 0
               Order by LA.Lottable05 Desc
               
               IF @c_Lot <> ''
               BEGIN
                  GOTO Retrieve_Lottables
               END
               ELSE
               BEGIN
                  -- If FromLoc do not have inventory get Lottable02 from any location in the warehouse for the same SKU without inventory
                  SELECT TOP 1 @c_Lot = LLI.LOT
                  FROM dbo.LotAttribute LA WITH (NOLOCK)
                  INNER JOIN dbo.LotxLocxID LLI WITH (NOLOCK) ON (LLI.Lot = LA.Lot AND LLI.SKU = LA.SKU AND LLI.StorerKey = LA.StorerKey)
                  WHERE LLI.SKU       = @c_SKU
                    AND LLI.StorerKey = @c_StorerKey 
                    AND LLI.Loc       <> @c_Loc
                  Order by LA.Lottable05 Desc
               END
            END
            
            Retrieve_Lottables:
            SELECT 
                @c_Lottable02 = Lottable02
               ,@c_Lottable03 = Lottable03
            FROM dbo.LotAttribute WITH (NOLOCK) 
            WHERE Lot = @c_Lot
         END
      END
   END

     
QUIT:
END -- End Procedure


GO