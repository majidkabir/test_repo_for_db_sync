SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_729GetUCCInfo01                                 */
/*                                                                      */
/* Purpose: Get UCC info                                                */
/*                                                                      */
/* Called from: rdtfnc_UCCInquire                                       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 16-Feb-2017 1.0  James      WMS1074 - Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_729GetUCCInfo01] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cUCC             NVARCHAR( 20),  
   @cExtInfo01       NVARCHAR( 20)  OUTPUT, 
   @cExtInfo02       NVARCHAR( 20)  OUTPUT, 
   @cExtInfo03       NVARCHAR( 20)  OUTPUT, 
   @cExtInfo04       NVARCHAR( 20)  OUTPUT, 
   @cExtInfo05       NVARCHAR( 20)  OUTPUT, 
   @cExtInfo06       NVARCHAR( 20)  OUTPUT, 
   @cExtInfo07       NVARCHAR( 20)  OUTPUT, 
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 20)  OUTPUT 
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE 
      @cUdf06     NVARCHAR( 60),
      @cUdf07     NVARCHAR( 60),
      @cUdf08     NVARCHAR( 60),
      @cUdf09     NVARCHAR( 60),
      @cUdf10     NVARCHAR( 60),
      @nU06Exists INT,
      @nU07Exists INT,
      @nU08Exists INT,
      @nU09Exists INT,
      @nU10Exists INT,
      @cDisplay   NVARCHAR( 20),
      @n          INT

      SET @cUdf06 = ''
      SET @cUdf07 = ''
      SET @cUdf08 = ''
      SET @cUdf09 = ''
      SET @cUdf10 = ''
      SET @nU06Exists = 0
      SET @nU07Exists = 0
      SET @nU08Exists = 0
      SET @nU09Exists = 0
      SET @nU10Exists = 0

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 1
      BEGIN
         CREATE TABLE #Display (
         Rowref   INT IDENTITY(1,1) NOT NULL,
         Display  NVARCHAR(20) NULL)

         SET @cExtInfo01 = ''
         SET @cExtInfo02 = SUBSTRING( rdt.rdtgetmessage( 106151, @cLangCode, 'DSP'), 6, 15)

         -- Sometimes UCC might contain multi sku and so is different udf06-udf10 value. 
         -- Need loop each one of them and get the VAS code to display
         DECLARE CUR_GETDISPLAY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT Userdefined06, Userdefined07, Userdefined08, Userdefined09, Userdefined10
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCC
         OPEN CUR_GETDISPLAY
         FETCH NEXT FROM CUR_GETDISPLAY INTO @cUdf06, @cUdf07, @cUdf08, @cUdf09, @cUdf10
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            -- sequence to display for nike sdc is 10, 6, 7, 8, 9
            -- if it was inserted to #Display before then no need to display again
            IF ISNULL( @cUdf10, '') = '1' AND @nU10Exists = 0
            BEGIN
               INSERT INTO #Display (Display) 
               SELECT SUBSTRING( ISNULL( Notes, ''), 1, 20)
               FROM dbo.CodeLkUp WITH (NOLOCK)
               WHERE ListName = 'PreRcvLane'
               AND   StorerKey = @cStorerKey
               AND   Code = '001'

               SET @nU10Exists = 1
            END

            IF ISNULL( @cUdf06, '') = '1' AND @nU06Exists = 0
            BEGIN
               INSERT INTO #Display (Display) 
               SELECT SUBSTRING( ISNULL( Notes, ''), 1, 20)
               FROM dbo.CodeLkUp WITH (NOLOCK)
               WHERE ListName = 'PreRcvLane'
               AND   StorerKey = @cStorerKey
               AND   Code = '002'

               SET @nU06Exists = 1
            END

            IF ISNULL( @cUdf07, '') = '1' AND @nU07Exists = 0
            BEGIN
               INSERT INTO #Display (Display) 
               SELECT SUBSTRING( ISNULL( Notes, ''), 1, 20)
               FROM dbo.CodeLkUp WITH (NOLOCK)
               WHERE ListName = 'PreRcvLane'
               AND   StorerKey = @cStorerKey
               AND   Code = '003'

               SET @nU07Exists = 1
            END

            IF ISNULL( @cUdf08, '') = '1' AND @nU08Exists = 0
            BEGIN
               INSERT INTO #Display (Display) 
               SELECT SUBSTRING( ISNULL( Notes, ''), 1, 20)
               FROM dbo.CodeLkUp WITH (NOLOCK)
               WHERE ListName = 'PreRcvLane'
               AND   StorerKey = @cStorerKey
               AND   Code = '004'

               SET @nU08Exists = 1
            END

            IF ISNULL( @cUdf09, '') = '1' AND @nU09Exists = 0
            BEGIN
               INSERT INTO #Display (Display) 
               SELECT SUBSTRING( ISNULL( Notes, ''), 1, 20)
               FROM dbo.CodeLkUp WITH (NOLOCK)
               WHERE ListName = 'PreRcvLane'
               AND   StorerKey = @cStorerKey
               AND   Code = '005'

               SET @nU09Exists = 1
            END

            FETCH NEXT FROM CUR_GETDISPLAY INTO @cUdf06, @cUdf07, @cUdf08, @cUdf09, @cUdf10
         END
         CLOSE CUR_GETDISPLAY
         DEALLOCATE CUR_GETDISPLAY

         SET @n = 1

         DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT Display FROM #Display
         ORDER BY RowRef
         OPEN CUR_LOOP
         FETCH NEXT FROM CUR_LOOP INTO @cDisplay
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF @n = 1
               SET @cExtInfo03 = '1.' + @cDisplay

            IF @n = 2
               SET @cExtInfo04 = '2.' + @cDisplay

            IF @n = 3
               SET @cExtInfo05 = '3.' + @cDisplay

            IF @n = 4
               SET @cExtInfo06 = '4.' + @cDisplay

            IF @n = 5
               SET @cExtInfo07 = '5.' + @cDisplay

            SET @n = @n + 1
            FETCH NEXT FROM CUR_LOOP INTO @cDisplay
         END
         CLOSE CUR_LOOP
         DEALLOCATE CUR_LOOP
      END
   END

   Quit:

SET QUOTED_IDENTIFIER OFF

GO