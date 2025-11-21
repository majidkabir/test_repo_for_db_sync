SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_841ExtValidSP05                                 */
/* Purpose:                                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-10-24 1.0  YeeKung    WMS-23944. Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_841ExtValidSP05] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR(3),
   @nStep       INT,
   @cStorerKey  NVARCHAR(15),
   @cDropID     NVARCHAR(20),
   @cSKU        NVARCHAR(20),
   @cPickSlipNo NVARCHAR(10),
   @cSerialNo   NVARCHAR( 30),
   @nSerialQTY  INT,
   @nErrNo      INT       OUTPUT,
   @cErrMsg     CHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nInputKey      INT
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cCartonType NVARCHAR (20)

   SELECT @nInputKey = InputKey,
          @cLoadKey = I_Field03,
          @cCartonType=V_string47
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
         DECLARE @cSalesman NVARCHAR(20),
                 @cTrackingNo NVARCHAR(20),
                 @cOrderkey   NVARCHAR(20)

         DECLARE CUR_ORDER CURSOR for
         SELECT   O.ORDERKEY,TRACKINGNO,SALESMAN
         FROM dbo.PICKDETAIL PD WITH (NOLOCK)          
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey          
            INNER JOIN dbo.LoadPlanDetail LD WITH (NOLOCK) ON LD.OrderKey = O.OrderKey   
         WHERE PD.Storerkey = @cStorerkey          
            AND ISNULL(O.ECOM_SINGLE_Flag,'') <> ''           
            AND PD.Qty > 0          
            AND PD.DropID = @cDropID          
            AND PD.CaseID = ''          
            AND (PD.Status IN ( '3', '5' ) OR PD.ShipFlag = 'P')  


         OPEN CUR_ORDER
         FETCH NEXT FROM CUR_ORDER INTO @cOrderkey,@cSalesman,@cTrackingNo
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF ISNULL(@cTrackingNo,'')<>''
            BEGIN
               IF EXISTS( SELECT 1 
         	               FROM dbo.CODELKUP WITH (NOLOCK)
         	               WHERE LISTNAME = 'COURIERLBL'
         	               AND   Code = @cSalesman
         	               AND   Storerkey = @cStorerkey
         	               AND   UDF05 ='Y')
               BEGIN  
                  SET @nErrNo = 207801
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackigNoNULL
                  GOTO QUIT
               END
            END

             FETCH NEXT FROM CUR_ORDER INTO @cOrderkey,@cSalesman,@cTrackingNo
         END

      END
   END

QUIT:



GO