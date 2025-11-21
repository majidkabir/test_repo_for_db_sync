SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp860LblNoDecode01                                 */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Decode SSCC no using the prefix setup in CODELKUP           */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 05-05-2015  1.0  James       SOS335929 Created                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp860LblNoDecode01]
   @c_LabelNo          NVARCHAR(40),
   @c_Storerkey        NVARCHAR(15),
   @c_ReceiptKey       NVARCHAR(10),
   @c_POKey            NVARCHAR(10),
	@cLangCode	        NVARCHAR(3),
	@c_oFieled01        NVARCHAR(20) OUTPUT,
	@c_oFieled02        NVARCHAR(20) OUTPUT,
   @c_oFieled03        NVARCHAR(20) OUTPUT,
   @c_oFieled04        NVARCHAR(20) OUTPUT,
   @c_oFieled05        NVARCHAR(20) OUTPUT,
   @c_oFieled06        NVARCHAR(20) OUTPUT,
   @c_oFieled07        NVARCHAR(20) OUTPUT,
   @c_oFieled08        NVARCHAR(20) OUTPUT,
   @c_oFieled09        NVARCHAR(20) OUTPUT,
   @c_oFieled10        NVARCHAR(20) OUTPUT,
   @b_Success          INT = 1  OUTPUT,
   @nErrNo             INT      OUTPUT, 
   @cErrMsg            NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE  @n_First  INT,
            @n_Middle INT,
            @n_Last   INT,
            @n_Start  INT,
            @n_Step   INT, 
            @b_debug  INT, 
            @c_Code   NVARCHAR( 10) 

   SET @b_debug = 0

   IF ISNULL( @c_LabelNo, '') = ''
      GOTO Quit

   SELECT @n_Step = Step FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE UserName = sUser_sName()
   SET @n_Step = 2
   IF @n_Step = 2
   BEGIN
      SET @c_oFieled01 = ''

      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT CODE FROM dbo.CODELKUP WITH (NOLOCK) 
      WHERE ListName = 'RMVCTNPRFX'
      AND   StorerKey =  @c_Storerkey
      ORDER BY Short
      OPEN CUR_LOOP
      FETCH NEXT FROM CUR_LOOP INTO @c_Code
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         --1. Check if the pattern match
         IF CHARINDEX(RTRIM( @c_Code), @c_LabelNo) > 0
         BEGIN
            SELECT @n_Start = CHARINDEX(RTRIM( @c_Code), @c_LabelNo)

            SELECT @n_First  = CHARINDEX( LEFT( @c_Code, 1), @c_LabelNo, @n_Start)

            SELECT @n_Middle  = CHARINDEX( RIGHT( @c_Code, 1), @c_LabelNo, @n_Start)

            SELECT @n_Last = CHARINDEX( LEFT( @c_Code, 1), @c_LabelNo, @n_Middle)

            IF @b_debug = 1
               SELECT '@n_Start', @n_Start, '@n_First', @n_First, '@n_Middle', @n_Middle, '@n_Last', @n_Last

            IF @n_Last > 0
               SELECT @c_oFieled01 = SUBSTRING( @c_LabelNo, @n_Middle + 1, @n_Last - (@n_Middle + 1))
            ELSE
               SELECT @c_oFieled01 = SUBSTRING( @c_LabelNo, @n_Middle + 1, LEN( @c_LabelNo) - @n_Middle)

            IF ISNULL( @c_oFieled01, '') <> ''
               BREAK
         END
         FETCH NEXT FROM CUR_LOOP INTO @c_Code
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END
     
QUIT:

END -- End Procedure

GO