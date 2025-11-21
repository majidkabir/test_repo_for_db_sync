SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1641ExtUpdVLT                                   */
/* Copyright      : Maersk                                              */
/* Customer       : Violet                                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev    Author        Purposes                             */
/* 2014-12-04 1.0.0  PPA374        UWP-27889 Create                     */
/************************************************************************/

CREATE     PROCEDURE [RDT].[rdt_1641ExtUpdVLT] (
   @nMobile        INT,  
   @nFunc          INT,  
   @cLangCode      NVARCHAR( 3),  
   @cUserName      NVARCHAR( 18),  
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15),  
   @cDropID        NVARCHAR( 20),  
   @cUCCNo         NVARCHAR( 20),  
   @nErrNo         INT           OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @nStep     INT,
      @nInputKey INT

   SELECT TOP 1 
      @nStep = Step, 
      @nInputKey = InputKey 
   FROM rdt.RDTMOBREC WITH(NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nFunc = 1641
   BEGIN
      IF @nStep = 3
      BEGIN
         IF @nInputKey = 1 
         BEGIN
            IF(SELECT TOP 1 UserDefine10 FROM dbo.orders WITH(NOLOCK) 
               WHERE orderkey = (SELECT TOP 1 orderkey FROM dbo.PICKHEADER WITH(NOLOCK) 
                                 WHERE PickHeaderKey = (SELECT TOP 1 PickSlipNo FROM PackDetail (NOLOCK) WHERE Dropid = @cUCCNo))) 
               NOT IN ('Non-Parcel','')
            BEGIN
               UPDATE dbo.Dropid WITH(ROWLOCK)
               SET loadkey = (SELECT TOP 1 Loadkey FROM dbo.Dropid WITH(NOLOCK) WHERE Dropid = @cUCCNo)
               WHERE Dropid = @cDropID AND Loadkey = ''

               UPDATE dbo.Dropid WITH(ROWLOCK)
               SET UDF01 = (SELECT TOP 1 mbolkey FROM dbo.orders WITH(NOLOCK) WHERE orderkey = (SELECT TOP 1 orderkey FROM dbo.PICKHEADER WITH(NOLOCK) WHERE PickHeaderKey = (SELECT TOP 1 PickSlipNo FROM dbo.PackDetail (NOLOCK) WHERE Dropid = @cUCCNo)))
               ,UDF02 = (SELECT TOP 1 orderkey FROM dbo.PICKHEADER WITH(NOLOCK) WHERE PickHeaderKey = (SELECT TOP 1 PickSlipNo FROM dbo.PackDetail WITH(NOLOCK) WHERE Dropid = @cUCCNo))
               WHERE Dropid = @cDropID AND UDF01 = ''
            END
         END
      END
      ELSE IF @nStep = 4
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF (SELECT TOP 1 UserDefine10 FROM dbo.orders WITH(NOLOCK) 
               WHERE orderkey = (SELECT TOP 1 UDF02 FROM dbo.Dropid WHERE Dropid = @cDropID)) 
               NOT IN ('Non-Parcel','')
            BEGIN
               UPDATE dbo.Dropid WITH(ROWLOCK)
               SET status = '5', LabelPrinted = 'Y'
               WHERE Dropid = @cDropID AND (LabelPrinted <> 'Y' or status <> '5')
            END

            IF (SELECT TOP 1 UserDefine10 FROM dbo.orders (NOLOCK) 
               WHERE orderkey = (SELECT TOP 1 orderkey FROM dbo.PICKHEADER WITH(NOLOCK) 
                                 WHERE PickHeaderKey = (SELECT TOP 1 PickSlipNo FROM dbo.PackDetail WITH(NOLOCK) WHERE Dropid = @cDropID))) 
               IN ('Non-Parcel','')
            BEGIN
               ;WITH CTE AS
               (SELECT 
                  MAX(CASE WHEN Dropid = @cDropID THEN CartonNo ELSE NULL END)OVER(PARTITION BY 1)NewCartonNo, 
                  MAX(CASE WHEN Dropid = @cDropID THEN LabelNo ELSE NULL END)OVER(PARTITION BY 1)NewLabelNo,
                  CASE WHEN Dropid = @cDropID THEN LabelLine ELSE
                  RIGHT('00000' + CAST(MAX(CASE WHEN Dropid = @cDropID THEN LabelLine ELSE NULL END)OVER(PARTITION BY 1)+
                  ROW_NUMBER()OVER(PARTITION BY CASE WHEN dropid = @cDropID THEN 0 ELSE 1 END ORDER BY Dropid, adddate) AS NVARCHAR(10)),5)END NewLabelLine,
                  @cDropID NewDropID, DropID, AddDate, SKU, LabelLine, CartonNo, LabelNo, Qty
               FROM dbo.PackDetail WITH(NOLOCK)
               WHERE Dropid IN 
                  (SELECT ChildId FROM dbo.DropidDetail WITH(NOLOCK) WHERE Dropid = @cDropID
                  UNION
                  SELECT @cDropID)
               )

               UPDATE CTE
               SET CartonNo = NewCartonNo, LabelNo = NewLabelNo, LabelLine = NewLabelLine, DropID = NewDropID
               WHERE EXISTS
                  (SELECT 1 FROM dbo.PackDetail PD WITH(NOLOCK)
                  WHERE PD.DropID = CTE.DropID AND PD.AddDate = CTE.AddDate AND PD.SKU = CTE.SKU AND PD.LabelLine = CTE.LabelLine AND PD.CartonNo = CTE.CartonNo 
                  AND PD.LabelNo = CTE.LabelNo AND PD.Qty = CTE.Qty)

               DELETE FROM dbo.Dropid
               WHERE dropid IN (SELECT ChildId FROM dbo.DropidDetail (NOLOCK) WHERE Dropid = @cDropID)

               DELETE FROM dbo.DropidDetail
               WHERE Dropid = @cDropID
            END
         END
      END
   END
END


GO