SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispLot6BondNonBond                                  */
/* Creation Date: 04-Mar-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#333117 - Project Merlion_Lottable06_Validation          */
/* Called By: of_lottable_default_roles                                 */
/*          : n_cst_receiptdetail.Event ue_sku_rule                     */
/*          : n_cst_transferdetail.Event ue_tosku_rule                  */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispLot6BondNonBond]
     @c_Storerkey        NVARCHAR(15)
   , @c_Sku              NVARCHAR(20)
   , @c_Lottable01Value  NVARCHAR(18)
   , @c_Lottable02Value  NVARCHAR(18)
   , @c_Lottable03Value  NVARCHAR(18)
   , @dt_Lottable04Value DATETIME
   , @dt_Lottable05Value DATETIME
   , @c_Lottable06Value  NVARCHAR(30)
   , @c_Lottable07Value  NVARCHAR(30)
   , @c_Lottable08Value  NVARCHAR(30)
   , @c_Lottable09Value  NVARCHAR(30)
   , @c_Lottable10Value  NVARCHAR(30)
   , @c_Lottable11Value  NVARCHAR(30)
   , @c_Lottable12Value  NVARCHAR(30)
   , @dt_Lottable13Value DATETIME
   , @dt_Lottable14Value DATETIME                                 
   , @dt_Lottable15Value DATETIME                               
   , @c_Lottable01       NVARCHAR(18)       OUTPUT                           
   , @c_Lottable02       NVARCHAR(18)       OUTPUT                           
   , @c_Lottable03       NVARCHAR(18)       OUTPUT
   , @dt_Lottable04      DATETIME           OUTPUT
   , @dt_Lottable05      DATETIME           OUTPUT
   , @c_Lottable06       NVARCHAR(30)       OUTPUT
   , @c_Lottable07       NVARCHAR(30)       OUTPUT
   , @c_Lottable08       NVARCHAR(30)       OUTPUT
   , @c_Lottable09       NVARCHAR(30)       OUTPUT
   , @c_Lottable10       NVARCHAR(30)       OUTPUT
   , @c_Lottable11       NVARCHAR(30)       OUTPUT
   , @c_Lottable12       NVARCHAR(30)       OUTPUT
   , @dt_Lottable13      DATETIME           OUTPUT
   , @dt_Lottable14      DATETIME           OUTPUT
   , @dt_Lottable15      DATETIME           OUTPUT
   , @b_Success          INT = 1            OUTPUT
   , @n_Err              INT = 0            OUTPUT
   , @c_Errmsg           NVARCHAR(250) = '' OUTPUT
   , @c_Sourcekey        NVARCHAR(15)  = ''
   , @c_Sourcetype       NVARCHAR(20)  = ''
   , @c_LottableLabel    NVARCHAR(20)  = ''
   , @c_Type             NVARCHAR(10)  = ''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_IsRDT INT
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

   -- RDT checking
   IF @n_IsRDT = 1
   BEGIN
      -- Get mobile info
      DECLARE @cLangCode NVARCHAR(3)
      SELECT @cLangCode = Lang_Code FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = SUSER_SNAME()

      -- PRE checking
      IF @c_Type = 'PRE' OR @c_Type = 'BOTH'
      BEGIN
         -- L6 blank
         IF @c_Lottable06Value = ''
            -- Get L6 default value
            SELECT @c_Lottable06 = Code
        FROM CodeLKUP WITH (NOLOCK)
            WHERE ListName = 'BONDFAC'
               AND StorerKey = @c_StorerKey
               AND (Short = 'BONDED' OR Short = 'NONBONDED')
               AND Long = 'DEFAULT'
      END
   
      -- POST checking
      IF @c_Type = 'POST' OR @c_Type = 'BOTH'
      BEGIN
         -- Check bond / non-bond
         IF NOT EXISTS( SELECT 1
            FROM CodeLKUP WITH (NOLOCK)
            WHERE ListName = 'BONDFAC'
               AND StorerKey = @c_StorerKey
               AND Code = @c_Lottable06Value
               AND (Short = 'BONDED' OR Short = 'NONBONDED'))
         BEGIN
            SET @n_Err = 52651
            SET @c_Errmsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP') -- L6 Bond/Unbond
         END
      END

      GOTO Quit
   END

   IF @c_Sourcetype NOT IN ('RECEIPT', 'TRADERETURN', 'TRANSFER', 'PO') -- (Wan01) Add PO
   BEGIN
      GOTO Quit
   END

   IF ISNULL(RTRIM(@c_Lottable06Value),'') = ''
   BEGIN
      SELECT TOP 1 @c_Lottable06 = RTRIM(CL.Code)
      FROM CODELKUP CL WITH (NOLOCK)
      WHERE CL.ListName = 'BONDFAC'
      AND   CL.Storerkey= @c_Storerkey
      AND   CL.Long = 'DEFAULT'
   END

Quit:

END

GO