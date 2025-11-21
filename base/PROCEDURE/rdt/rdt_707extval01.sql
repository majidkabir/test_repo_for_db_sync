SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_707ExtVal01                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 22-Dec-2022 1.0  yeekung    WMS21376. Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_707ExtVal01] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @tVar             VariableTable READONLY,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cRef01      NVARCHAR( 60)
   DECLARE @cRef02      NVARCHAR( 60)
   DECLARE @cRef03      NVARCHAR( 60)
   DECLARE @cRef04      NVARCHAR( 60)
   DECLARE @cRef05      NVARCHAR( 60)
   DECLARE @cUDF01      NVARCHAR( 60)
   DECLARE @cUDF02      NVARCHAR( 60)
   DECLARE @cUDF03      NVARCHAR( 60)
   DECLARE @cUDF04      NVARCHAR( 60)
   DECLARE @cUDF05      NVARCHAR( 60)
   DECLARE @cRefValue   NVARCHAR( 60)
   DECLARE @cJobType    NVARCHAR( 20)
   DECLARE @cUserID     NVARCHAR( 20)
   DECLARE @cUserID01    NVARCHAR( 20)  
   DECLARE @cUserID02     NVARCHAR( 20)   
   DECLARE @cUserID03     NVARCHAR( 20)   
   DECLARE @cUserID04     NVARCHAR( 20)   
   DECLARE @cUserID05     NVARCHAR( 20)   
   DECLARE @cUserID06     NVARCHAR( 20)
   DECLARE @cUserID07     NVARCHAR( 20)   
   DECLARE @cUserID08     NVARCHAR( 20)
   DECLARE @cUserID09     NVARCHAR( 20)   



   -- Variable mapping
   SELECT @cUserID = ISNULL( Value, '') FROM @tVar WHERE Variable = '@cUserID'
   SELECT @cUserID01 = ISNULL( Value, '') FROM @tVar WHERE Variable = '@cUserID01'
   SELECT @cUserID02 = ISNULL( Value, '') FROM @tVar WHERE Variable = '@cUserID02'
   SELECT @cUserID03 = ISNULL( Value, '') FROM @tVar WHERE Variable = '@cUserID03'
   SELECT @cUserID04 = ISNULL( Value, '') FROM @tVar WHERE Variable = '@cUserID04'
   SELECT @cUserID05 = ISNULL( Value, '') FROM @tVar WHERE Variable = '@cUserID05'
   SELECT @cUserID06 = ISNULL( Value, '') FROM @tVar WHERE Variable = '@cUserID06'
   SELECT @cUserID07 = ISNULL( Value, '') FROM @tVar WHERE Variable = '@cUserID07'
   SELECT @cUserID08 = ISNULL( Value, '') FROM @tVar WHERE Variable = '@cUserID08'
   SELECT @cUserID09 = ISNULL( Value, '') FROM @tVar WHERE Variable = '@cUserID09'


   SELECT @cJobType = ISNULL( Value, '') FROM @tVar WHERE Variable = '@cJobType'


   IF @nFunc = 707 -- Data capture 9
   BEGIN
      IF @nStep = 1 -- userid
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF EXISTS (SELECT 1
               FROM rdt.rdtWATLog WITH (NOLOCK)
               WHERE Module = 'JOBCAPTURE' 
               AND USERNAME = @cUserID
               AND   StorerKey = @cStorerKey
               AND    status NOT IN ('9',''))
            BEGIN
               SET @nErrNo = 195151
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --705JobCptNotDone
               GOTO Quit
            END
         END   -- InputKey
      END   -- Step

      IF @nStep = 2 -- capture group user 
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
             IF EXISTS (SELECT 1
               FROM rdt.rdtWATLog WITH (NOLOCK)
               WHERE Module = 'GrpJbCap' 
               AND USERNAME in (@cUserID01,@cUserID02,@cUserID03,@cUserID04,@cUserID05,@cUserID06,@cUserID07,@cUserID08,@cUserID09)
               AND   StorerKey = @cStorerKey
               AND   status NOT IN ('9',''))
            BEGIN
               SET @nErrNo = 195152
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --707GrpCptNotDone
               GOTO Quit
            END

            IF EXISTS (SELECT 1
               FROM rdt.rdtWATLog WITH (NOLOCK)
               WHERE Module = 'JOBCAPTURE' 
               AND USERNAME in (@cUserID01,@cUserID02,@cUserID03,@cUserID04,@cUserID05,@cUserID06,@cUserID07,@cUserID08,@cUserID09)
               AND   StorerKey = @cStorerKey
               AND    status NOT IN ('9',''))
            BEGIN
               SET @nErrNo = 195153
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --705JobCptNotDone
               GOTO Quit
            END

           IF EXISTS (SELECT 1
            FROM rdt.rdtWATLog WL (NOLOCK)   
            JOIN RDT.rdtwatteamlog WRL (NOLOCK) ON WL.ROWREF = WRL.UDF01
            WHERE Module = 'GrpJbCap' 
            AND  WRL.MEMBERUSER  in (@cUserID01,@cUserID02,@cUserID03,@cUserID04,@cUserID05,@cUserID06,@cUserID07,@cUserID08,@cUserID09)
            AND   WRL.StorerKey = @cStorerKey
            AND   WL.status NOT IN ('9',''))
            BEGIN
               SET @nErrNo = 195154
               SET @cErrMsg =rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --707GrpCptNotDone
               GOTO Quit
            END
         END   -- InputKey
      END   -- Step
   END   -- Func

   Quit:
END

GO