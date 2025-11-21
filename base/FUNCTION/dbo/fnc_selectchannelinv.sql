SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Function: fnc_SelectChannelInv                                       */
/* Creation Date: 2023-05-03                                            */
/* Copyright: Maersk                                                    */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: Get Channel Inventory By Channel, Qty                       */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2023-05-03  Wan02    1.2   LFWM-4072 - [CN] PROD_Mannings Populate   */
/*                            Transfer By UCC function needs to be fixed*/
/*                            in Transfer screen                        */
/*                            DevOps Combine Script                     */
/************************************************************************/
CREATE   FUNCTION [dbo].[fnc_SelectChannelInv]
(
   @c_Facility    NVARCHAR(5)
,  @c_StorerKey   NVARCHAR(15)
,  @c_SKU         NVARCHAR(20)
,  @c_Channel     NVARCHAR(20)   = ''
,  @c_Lot         NVARCHAR(10)
,  @n_Qty         INT            = 0
)
RETURNS @tChannelInv TABLE
(  Channel_ID     BIGINT
,  Channel        NVARCHAR(20) 
,  Qty            INT
,  QtyAllocated   INT
,  QtyOnHold      INT
,  C_Attribute01  NVARCHAR(30)
,  C_Attribute02  NVARCHAR(30)
,  C_Attribute03  NVARCHAR(30)
,  C_Attribute04  NVARCHAR(30)
,  C_Attribute05  NVARCHAR(30)
)
AS
BEGIN
   DECLARE @n_Cnt                INT         = 0
         , @n_Channel_ID         BIGINT      = 0
         , @n_QtyAllocated       INT         = 0
         , @n_QtyOnHold          INT         = 0
         , @c_C_AttributeLbl01   NVARCHAR(30)=''
         , @c_C_AttributeLbl02   NVARCHAR(30)=''
         , @c_C_AttributeLbl03   NVARCHAR(30)=''
         , @c_C_AttributeLbl04   NVARCHAR(30)=''
         , @c_C_AttributeLbl05   NVARCHAR(30)=''
         , @c_C_Attribute01      NVARCHAR(30)=''
         , @c_C_Attribute02      NVARCHAR(30)=''
         , @c_C_Attribute03      NVARCHAR(30)=''
         , @c_C_Attribute04      NVARCHAR(30)=''
         , @c_C_Attribute05      NVARCHAR(30)=''
         , @c_Lottable01         NVARCHAR(30)=''
         , @c_Lottable02         NVARCHAR(30)=''
         , @c_Lottable03         NVARCHAR(30)=''
         , @c_Lottable04         DATETIME
         , @c_Lottable05         DATETIME
         , @c_Lottable06         NVARCHAR(30)=''
         , @c_Lottable07         NVARCHAR(30)=''
         , @c_Lottable08         NVARCHAR(30)=''
         , @c_Lottable09         NVARCHAR(30)=''
         , @c_Lottable10         NVARCHAR(30)=''
         , @c_Lottable11         NVARCHAR(30)=''
         , @c_Lottable12         NVARCHAR(30)=''
         , @c_Lottable13         DATETIME
         , @c_Lottable14         DATETIME
         , @c_Lottable15         DATETIME

   IF ISNULL(RTRIM(@c_Lot), '') = ''
   BEGIN
      GOTO EXIT_FUNCTION
   END

   IF ISNULL(RTRIM(@c_Facility), '') = ''
   BEGIN
      GOTO EXIT_FUNCTION
   END

   IF ISNULL(RTRIM(@c_StorerKey), '') = ''
   BEGIN
      GOTO EXIT_FUNCTION
   END

   IF ISNULL(RTRIM(@c_Sku), '') = ''
   BEGIN
      GOTO EXIT_FUNCTION
   END

   IF ISNULL(RTRIM(@c_Channel), '') = '' AND @n_Qty = 0
   BEGIN
      GOTO EXIT_FUNCTION
   END

   SELECT @n_Cnt = 1
         ,@c_C_AttributeLbl01 = cac.C_AttributeLabel01
         ,@c_C_AttributeLbl02 = cac.C_AttributeLabel02
         ,@c_C_AttributeLbl03 = cac.C_AttributeLabel03
         ,@c_C_AttributeLbl04 = cac.C_AttributeLabel04
         ,@c_C_AttributeLbl05 = cac.C_AttributeLabel05
   FROM   ChannelAttributeConfig AS cac WITH(NOLOCK)
   WHERE  cac.StorerKey = @c_StorerKey

   IF @n_Cnt = 0
   BEGIN
      GOTO EXIT_FUNCTION
   END

   SELECT @c_Lottable01 = Lottable01
         ,@c_Lottable02 = Lottable02
         ,@c_Lottable03 = Lottable03
         ,@c_Lottable04 = Lottable04
         ,@c_Lottable05 = Lottable05
         ,@c_Lottable06 = Lottable06
         ,@c_Lottable07 = Lottable07
         ,@c_Lottable08 = Lottable08
         ,@c_Lottable09 = Lottable09
         ,@c_Lottable10 = Lottable10
         ,@c_Lottable11 = Lottable11
         ,@c_Lottable12 = Lottable12
         ,@c_Lottable13 = Lottable13
         ,@c_Lottable14 = Lottable14
         ,@c_Lottable15 = Lottable15
   FROM LOTATTRIBUTE WITH (NOLOCK)
   WHERE Lot = @c_Lot

   SET @c_C_Attribute01 = CASE @c_C_AttributeLbl01
                          WHEN 'Lottable01' THEN @c_Lottable01
                          WHEN 'Lottable02' THEN @c_Lottable02
                          WHEN 'Lottable03' THEN @c_Lottable03
                          WHEN 'Lottable04' THEN CONVERT(NVARCHAR(10), @c_Lottable04, 121)
                          WHEN 'Lottable05' THEN CONVERT(NVARCHAR(10), @c_Lottable05, 121)
                          WHEN 'Lottable06' THEN @c_Lottable06
                          WHEN 'Lottable07' THEN @c_Lottable07
                          WHEN 'Lottable08' THEN @c_Lottable08
                          WHEN 'Lottable09' THEN @c_Lottable09
                          WHEN 'Lottable10' THEN @c_Lottable10
                          WHEN 'Lottable11' THEN @c_Lottable11
                          WHEN 'Lottable12' THEN @c_Lottable12
                          WHEN 'Lottable13' THEN CONVERT(NVARCHAR(10), @c_Lottable13, 121)
                          WHEN 'Lottable14' THEN CONVERT(NVARCHAR(10), @c_Lottable14, 121)
                          WHEN 'Lottable15' THEN CONVERT(NVARCHAR(10), @c_Lottable15, 121)
                          ELSE ''
                          END

   SET @c_C_Attribute02 = CASE @c_C_AttributeLbl02
                          WHEN 'Lottable01' THEN @c_Lottable01
                          WHEN 'Lottable02' THEN @c_Lottable02
                          WHEN 'Lottable03' THEN @c_Lottable03
                          WHEN 'Lottable04' THEN CONVERT(NVARCHAR(10), @c_Lottable04, 121)
                          WHEN 'Lottable05' THEN CONVERT(NVARCHAR(10), @c_Lottable05, 121)
                          WHEN 'Lottable06' THEN @c_Lottable06
                          WHEN 'Lottable07' THEN @c_Lottable07
                          WHEN 'Lottable08' THEN @c_Lottable08
                          WHEN 'Lottable09' THEN @c_Lottable09
                          WHEN 'Lottable10' THEN @c_Lottable10
                          WHEN 'Lottable11' THEN @c_Lottable11
                          WHEN 'Lottable12' THEN @c_Lottable12
                          WHEN 'Lottable13' THEN CONVERT(NVARCHAR(10), @c_Lottable13, 121)
                          WHEN 'Lottable14' THEN CONVERT(NVARCHAR(10), @c_Lottable14, 121)
                          WHEN 'Lottable15' THEN CONVERT(NVARCHAR(10), @c_Lottable15, 121)
                          ELSE ''
                          END

   SET @c_C_Attribute03 = CASE @c_C_AttributeLbl03
                          WHEN 'Lottable01' THEN @c_Lottable01
                          WHEN 'Lottable02' THEN @c_Lottable02
                          WHEN 'Lottable03' THEN @c_Lottable03
                          WHEN 'Lottable04' THEN CONVERT(NVARCHAR(10), @c_Lottable04, 121)
                          WHEN 'Lottable05' THEN CONVERT(NVARCHAR(10), @c_Lottable05, 121)
                          WHEN 'Lottable06' THEN @c_Lottable06
                          WHEN 'Lottable07' THEN @c_Lottable07
                          WHEN 'Lottable08' THEN @c_Lottable08
                          WHEN 'Lottable09' THEN @c_Lottable09
                          WHEN 'Lottable10' THEN @c_Lottable10
                          WHEN 'Lottable11' THEN @c_Lottable11
                          WHEN 'Lottable12' THEN @c_Lottable12
                          WHEN 'Lottable13' THEN CONVERT(NVARCHAR(10), @c_Lottable13, 121)
                          WHEN 'Lottable14' THEN CONVERT(NVARCHAR(10), @c_Lottable14, 121)
                          WHEN 'Lottable15' THEN CONVERT(NVARCHAR(10), @c_Lottable15, 121)
                          ELSE ''
                          END

   SET @c_C_Attribute04 = CASE @c_C_AttributeLbl04
                          WHEN 'Lottable01' THEN @c_Lottable01
                          WHEN 'Lottable02' THEN @c_Lottable02
                          WHEN 'Lottable03' THEN @c_Lottable03
                          WHEN 'Lottable04' THEN CONVERT(NVARCHAR(10), @c_Lottable04, 121)
                          WHEN 'Lottable05' THEN CONVERT(NVARCHAR(10), @c_Lottable05, 121)
                          WHEN 'Lottable06' THEN @c_Lottable06
                          WHEN 'Lottable07' THEN @c_Lottable07
                          WHEN 'Lottable08' THEN @c_Lottable08
                          WHEN 'Lottable09' THEN @c_Lottable09
                          WHEN 'Lottable10' THEN @c_Lottable10
                          WHEN 'Lottable11' THEN @c_Lottable11
                          WHEN 'Lottable12' THEN @c_Lottable12
                          WHEN 'Lottable13' THEN CONVERT(NVARCHAR(10), @c_Lottable13, 121)
                          WHEN 'Lottable14' THEN CONVERT(NVARCHAR(10), @c_Lottable14, 121)
                          WHEN 'Lottable15' THEN CONVERT(NVARCHAR(10), @c_Lottable15, 121)
                          ELSE ''
                          END

   SET @c_C_Attribute05 = CASE @c_C_AttributeLbl05
                          WHEN 'Lottable01' THEN @c_Lottable01
                          WHEN 'Lottable02' THEN @c_Lottable02
                          WHEN 'Lottable03' THEN @c_Lottable03
                          WHEN 'Lottable04' THEN CONVERT(NVARCHAR(10), @c_Lottable04, 121)
                          WHEN 'Lottable05' THEN CONVERT(NVARCHAR(10), @c_Lottable05, 121)
                          WHEN 'Lottable06' THEN @c_Lottable06
                          WHEN 'Lottable07' THEN @c_Lottable07
                          WHEN 'Lottable08' THEN @c_Lottable08
                          WHEN 'Lottable09' THEN @c_Lottable09
                          WHEN 'Lottable10' THEN @c_Lottable10
                          WHEN 'Lottable11' THEN @c_Lottable11
                          WHEN 'Lottable12' THEN @c_Lottable12
                          WHEN 'Lottable13' THEN CONVERT(NVARCHAR(10), @c_Lottable13, 121)
                          WHEN 'Lottable14' THEN CONVERT(NVARCHAR(10), @c_Lottable14, 121)
                          WHEN 'Lottable15' THEN CONVERT(NVARCHAR(10), @c_Lottable15, 121)
                          ELSE ''
                          END


   EXIT_FUNCTION:
     
   SELECT TOP 1
         @n_Channel_ID = CASE WHEN ci.Channel = @c_Channel AND @n_Qty > 0 AND ci.Qty >= @n_Qty THEN ci.Channel_ID
                              WHEN ci.Channel = @c_Channel THEN ci.Channel_ID
                              WHEN @n_Qty > 0 AND ci.Qty >= @n_Qty THEN ci.Channel_ID
                              ELSE 0
                              END 
      ,  @c_Channel     = ci.Channel 
      ,  @n_Qty         = ci.Qty
      ,  @n_QtyAllocated= ci.QtyAllocated
      ,  @n_QtyOnHold   = ci.QtyOnHold
   FROM ChannelInv AS ci WITH(NOLOCK) 
   WHERE ci.StorerKey = @c_StorerKey 
   AND   ci.SKU = @c_Sku 
   AND   ci.Facility = @c_Facility
   AND   ci.C_Attribute01 = @c_C_Attribute01 
   AND   ci.C_Attribute02 = @c_C_Attribute02 
   AND   ci.C_Attribute03 = @c_C_Attribute03 
   AND   ci.C_Attribute04 = @c_C_Attribute04 
   AND   ci.C_Attribute05 = @c_C_Attribute05 
   AND  ci.Channel <> ''
   ORDER BY  CASE WHEN ci.Channel = @c_Channel AND @n_Qty > 0 AND ci.Qty >= @n_Qty THEN 1
                  WHEN ci.Channel = @c_Channel THEN 2
                  WHEN @n_Qty > 0 AND ci.Qty >= @n_Qty THEN 3
                  ELSE 9
             END
             
   IF @n_Channel_ID > 0   
   BEGIN    
      INSERT INTO @tChannelInv (Channel_ID, Channel, Qty, QtyAllocated, QtyOnHold
                               ,C_Attribute01,C_Attribute02,C_Attribute03,C_Attribute04,C_Attribute05)
      VALUES (@n_Channel_ID, @c_Channel, @n_Qty, @n_QtyAllocated, @n_QtyOnHold
                               ,@c_C_Attribute01,@c_C_Attribute02,@c_C_Attribute03,@c_C_Attribute04,@c_C_Attribute05) 
   END 
                           
   RETURN
END

GO