SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_840GetOrders01                                  */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: Return orders using pickdetail.dropid                       */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2020-07-05  1.0  James       WMS-13913. Created                      */
/* 2020-10-22  1.1  James       WMS-13913 Add step 5 (james01)          */
/* 2020-11-02  1.2  LZG         Exclude shorted line (ZG01)             */ 
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_840GetOrders01]
   @nMobile                   INT,
   @nFunc                     INT,
   @cLangCode                 NVARCHAR( 3),
   @nStep                     INT,
   @nInputKey                 INT,
   @cStorerkey                NVARCHAR( 15),
   @cDropID                   NVARCHAR( 20),
   @tGetOrders                VariableTable READONLY,
   @cOrderKey                 NVARCHAR( 10) OUTPUT,
   @nErrNo                    INT           OUTPUT,
   @cErrMsg                   NVARCHAR( 20) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cTempOrderKey     NVARCHAR( 10)
   DECLARE @nCnt              INT
   
   SET @cOrderKey = ''
   
   IF @nStep IN ( 1, 5) -- OrderKey/DropID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Retrieve orderkey from pickdetail.dropid
         SELECT TOP 1 @cTempOrderKey = OrderKey
         FROM dbo.PICKDETAIL WITH (NOLOCK)
         WHERE Storerkey = @cStorerkey
         AND   DropID = @cDropID
         AND   [Status] < '9'
         AND   [Status] <> '4'        -- ZG01
         ORDER BY 1
         
         IF ISNULL( @cTempOrderKey, '') = ''
         BEGIN
            SET @nErrNo = 154551
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Orders 
            GOTO Quit
         END
         
         -- 1 tote only allow 1 discrete value of ECOM_SINGLE_Flag
         SET @nCnt = 0
         SELECT @nCnt = COUNT( DISTINCT ECOM_SINGLE_Flag)
         FROM dbo.PICKDETAIL PD WITH (NOLOCK)  
         JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
         WHERE PD.Storerkey = @cStorerkey
         AND   PD.DropID = @cDropID
         AND   PD.Status < '9'
         AND   PD.Status <> '4'        -- ZG01
         GROUP BY O.ECOM_SINGLE_Flag 

         IF @nCnt > 1
         BEGIN
            SET @nErrNo = 154552
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Sortation 
            GOTO Quit
         END
         
         -- If ECOM_SINGLE_Flag = 'M', only allow 1 orderkey
         IF EXISTS ( SELECT 1
                     FROM dbo.PICKDETAIL PD WITH (NOLOCK)  
                     JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
                     WHERE PD.Storerkey = @cStorerkey
                     AND   PD.DropID = @cDropID
                     --AND   PD.Status < '9'
                     AND   O.ECOM_SINGLE_Flag = 'M'
                     AND   EXISTS ( SELECT 1 FROM dbo.PackHeader PH WITH (NOLOCK) 
                                    WHERE PH.OrderKey = PD.OrderKey 
                                    AND   PH.Status < '9')
         )
         BEGIN
            SET @nCnt = 0
            SELECT @nCnt = COUNT( DISTINCT PD.OrderKey)
            FROM dbo.PICKDETAIL PD WITH (NOLOCK)  
            WHERE PD.Storerkey = @cStorerkey
            AND   PD.DropID = @cDropID
            --AND   Status < '9'
            AND   EXISTS ( SELECT 1 FROM dbo.PackHeader PH WITH (NOLOCK) 
                           WHERE PH.OrderKey = PD.OrderKey 
                           AND   PH.Status < '9')

            IF @nCnt > 1
            BEGIN
               SET @nErrNo = 154553
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Sortation 
               GOTO Quit
            END
         END
         
         SET @cOrderKey = @cTempOrderKey
      END
   END

Quit:
END

GO