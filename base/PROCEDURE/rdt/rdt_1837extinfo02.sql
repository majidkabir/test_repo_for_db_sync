SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1837ExtInfo02                                   */
/*                                                                      */
/* Purpose: Prompt screen when PPA carton scanned                       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2021-07-13  1.0  Chermaine   WMS-17386. Created                      */
/* 2022-01-13  1.1  James       Set field11 as default ExtInfo (james01)*/
/************************************************************************/

CREATE   PROC [RDT].[rdt_1837ExtInfo02] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cCartonID      NVARCHAR( 20), 
   @cPalletID      NVARCHAR( 20), 
   @cLoadKey       NVARCHAR( 10), 
   @cLoc           NVARCHAR( 10), 
   @cOption        NVARCHAR( 1), 
   @tExtValidate   VariableTable READONLY,
   @cExtendedInfo  NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cPickDetailCartonID NVARCHAR( 20),
           @cPickConfirmStatus  NVARCHAR( 1),
           @cSQL        NVARCHAR(MAX), 
           @cSQLParam   NVARCHAR(MAX),
           @nRowCount   INT
           
   DECLARE @cErrMsg01   NVARCHAR( 20), @cErrMsg06   NVARCHAR( 20),
           @cErrMsg02   NVARCHAR( 20), @cErrMsg07   NVARCHAR( 20),
           @cErrMsg03   NVARCHAR( 20), @cErrMsg08   NVARCHAR( 20),
           @cErrMsg04   NVARCHAR( 20), @cErrMsg09   NVARCHAR( 20),
           @cErrMsg05   NVARCHAR( 20), @cErrMsg10   NVARCHAR( 20)
           

   IF @nStep = 1 -- CartonID
   BEGIN
      IF @nInputKey = 1
      BEGIN
      	IF @cCartonID <> ''
      	BEGIN
            SET @cPickDetailCartonID = rdt.RDTGetConfig( @nFunc, 'PickDetailCartonID', @cStorerKey)
            IF @cPickDetailCartonID NOT IN ('DropID', 'CaseID')
               SET @cPickDetailCartonID = 'DropID'

            SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
            IF @cPickConfirmStatus = '0'  
               SET @cPickConfirmStatus = '5'  
            
            SELECT @cErrMsg01 = '', @cErrMsg06 = '',
                   @cErrMsg02 = '', @cErrMsg07 = '',
                   @cErrMsg03 = '', @cErrMsg08 = '',
                   @cErrMsg04 = '', @cErrMsg09 = '',
                   @cErrMsg05 = '', @cErrMsg10 = ''
      
      		--check CartonId hav PPA flag
      		SET @cSQL = 
               ' SELECT 1 ' + 
               ' FROM dbo.PickDetail pickDT WITH (NOLOCK) ' + 
               ' JOIN dbo.PackDetail packDt WITH (NOLOCK) on packDt.labelNo = pickDt.' + RTRIM( @cPickDetailCartonID) +
               ' JOIN dbo.PackInfo pkInfo WITH (NOLOCK) on (packDt.pickslipNo = pkInfo.pickSlipNo AND packDt.CartonNo = pkInfo.cartonno) ' +
               ' WHERE pickDT.StorerKey = @cStorerKey ' + 
                  ' AND pickDT.Status = ''' + @cPickConfirmStatus + '''' +  
                  ' AND pickDT.QTY > 0 ' + 
                  ' AND pickDT.' + RTRIM( @cPickDetailCartonID) + ' = @cCartonID ' +
                  ' AND pkInfo.RefNo = ''PPA'' ' +
                  ' ORDER BY 1 ' +
                  ' SET @nRowCount = @@ROWCOUNT '

            SET @cSQLParam = 
               ' @cStorerKey  NVARCHAR( 15), ' + 
               ' @cCartonID   NVARCHAR( 20), ' + 
               ' @nRowCount   INT  OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam
               ,@cStorerKey
               ,@cCartonID 
               ,@nRowCount OUTPUT
               
            IF @nRowCount > 0
            	SET @nErrNo = -1
            
            DECLARE @tCtn TABLE ( CartonID NVARCHAR( 20) NULL)
            
            INSERT INTO @tCtn ( CartonID)
            SELECT DISTINCT PD.CaseID
            FROM dbo.PICKDETAIL PD WITH (NOLOCK)  
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)  
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( LPD.OrderKey = PD.OrderKey)  
            WHERE PD.StorerKey = @cStorerKey  
            AND   PD.QTY > 0  
            AND   LPD.LoadKey = @cLoadKey  
            AND   LOC.Facility = @cFacility  
            AND   (LOC.LocationCategory NOT IN ('PACK&HOLD','PPS','Staging') OR PD.Status <> '5' OR PD.[Status] = '4')
            SELECT @nRowCount = @@ROWCOUNT
            
            IF @nRowCount = 0 OR @nRowCount > 1
               GOTO Quit

            IF @nRowCount = 1
            BEGIN
               SELECT @cExtendedInfo = Long 
               FROM dbo.CODELKUP WITH (NOLOCK) 
               WHERE ListName = 'RDTMsgQ'
               AND   Code = '10' 
               AND   StorerKey = @cStorerKey 
               AND   code2 = @nFunc 
               
               SET @nErrNo = -1
            END
      	END
      END
   END


   Quit:

END

GO