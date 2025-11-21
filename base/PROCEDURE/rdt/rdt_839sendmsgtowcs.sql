SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************************/
/* Store procedure: rdt_839SendMsgToWCS                                              */
/* Purpose:Trigger Msg to WMSC on ID level                                           */
/*                                                                                   */
/* Modifications log:                                                                */
/*                                                                                   */
/* Date         Author    Ver.    Purposes                                           */
/* 2023-12-01   Ung       1.0     WMS-24315                                          */
/* 2024-09-05   YYS027    1.1     FCR-771                                            */
/* 2024-11-08   YYS027    1.1.1   FCR-771 to add cursor for muiltible orderkeys      */
/*************************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_839SendMsgToWCS]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cDropID         NVARCHAR( 20)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess INT
   DECLARE @nExists  INT
   DECLARE @cShort   NVARCHAR(20)
   DECLARE @cWCS     NVARCHAR(1)

   DECLARE @cOrderKey      NVARCHAR( 10) = ''
          ,@cLoadKey       NVARCHAR( 10) = ''
          ,@cZone          NVARCHAR( 10) = ''
          ,@cPSType        NVARCHAR( 10) = ''
          ,@cDocType       NVARCHAR( 1) = ''
          ,@cOrderGroup    NVARCHAR( 20) = ''
          ,@nIsNoEmptyDropID INT = 0

   SET @nErrNo          = 0
   SET @cErrMSG         = ''

   --IF dbo.fnc_GetRight( @cFacility, @cStorerKey, '', 'WCS') <> '1'
   --BEGIN
   --   GOTO Quit
   --END

   IF @cDropID  =''
   BEGIN
      GOTO Quit
   END
   SELECT @cZone = Zone,
          @cLoadKey = LoadKey,
          @cOrderKey = OrderKey
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   -- Get PickSlip type
   IF @@ROWCOUNT = 0
      SET @cPSType = 'CUSTOM'
   ELSE
   BEGIN
      IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
         SET @cPSType = 'XD'
      ELSE IF @cOrderKey = ''
         SET @cPSType = 'CONSO'
      ELSE
         SET @cPSType = 'DISCRETE'
   END

   IF @cPSType = 'CUSTOM'
   BEGIN
      IF EXISTS(SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
                  AND DropID = @cDropID)
      BEGIN
         SET @nIsNoEmptyDropID = 1
      END
   END

   IF @cPSType = 'XD'
   BEGIN
      IF EXISTS(SELECT 1 FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                  WHERE RKL.PickSlipNo = @cPickSlipNo
                  AND PD.DropID = @cDropID)
      BEGIN
         SET @nIsNoEmptyDropID = 1
      END
   END

   IF @cPSType = 'DISCRETE'
   BEGIN
      IF EXISTS(SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                WHERE OrderKey = @cOrderKey
                  AND DropID = @cDropID)
      BEGIN
         SET @nIsNoEmptyDropID = 1
      END
   END
   IF @cPSType = 'CONSO'
   BEGIN
      IF EXISTS(SELECT 1 FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
                          JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
                WHERE LPD.LoadKey = @cLoadKey
                  AND PD.DropID = @cDropID)
      BEGIN
         SET @nIsNoEmptyDropID = 1
      END
   END
   --Move WCS checking of fnc_GetRight from header to here 
   IF dbo.fnc_GetRight( @cFacility, @cStorerKey, '', 'WCS') = '1'
   BEGIN
      IF @nIsNoEmptyDropID = 1
      BEGIN
         EXEC dbo.ispGenTransmitLog2
                        @c_TableName      = 'WSRDTTOTECFM',
                        @c_Key1           = @cPickSlipNo,
                        @c_Key2           = @cDropID,
                        @c_Key3           = @cStorerKey,
                        @c_TransmitBatch  = '',
                        @b_success        = @bSuccess    OUTPUT,
                        @n_err            = @nErrNo      OUTPUT,
                        @c_errmsg         = @cErrMsg     OUTPUT

         IF @bSuccess <> 1
         BEGIN
            SET @nErrNo = 249406
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS TLog2 Fail
            GOTO Quit
         END
      END
   END
   --add for FCR-771 
   --SELECT @cOrderKey=OrderKey FROM dbo.PICKDETAIL WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND DropID = @cDropID AND Storerkey = @cStorerKey AND ISNULL(@cOrderKey,'') = ''     --due for cross-dock, OrderKey is empty, so here ,re-query for @cOrderKey
   --IF dbo.fnc_GetRight( @cFacility, @cStorerKey, '', 'Innobec') = '1' AND EXISTS ( SELECT * FROM dbo.ORDERS WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Storerkey = @cStorerKey AND DocType = 'N' )
   IF dbo.fnc_GetRight( @cFacility, @cStorerKey, '', 'Innobec') = '1'
   BEGIN
      IF @nIsNoEmptyDropID = 1
      BEGIN
         IF ISNULL(@cOrderKey,'') <> '' 
         BEGIN
            IF EXISTS ( SELECT * FROM dbo.ORDERS WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Storerkey = @cStorerKey AND DocType = 'N' )
            BEGIN
               EXEC dbo.ispGenTransmitLog2
                              @c_TableName      = 'WSTOTECFMlb',
                              @c_Key1           = @cOrderKey,
                              @c_Key2           = @cDropID,
                              @c_Key3           = @cStorerKey,
                              @c_TransmitBatch  = '',
                              @b_success        = @bSuccess    OUTPUT,
                              @n_err            = @nErrNo      OUTPUT,
                              @c_errmsg         = @cErrMsg     OUTPUT

               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 249406
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS TLog2 Fail
                  GOTO Quit
               END
            END
         END
         ELSE
         BEGIN
            --@cOrderKey is empty. for this case, the result of query by PickSlipNo and DropID, maybe, have multible records
            DECLARE ordcur CURSOR LOCAL FOR 
               SELECT DISTINCT OrderKey FROM dbo.PICKDETAIL WITH (NOLOCK) 
                  WHERE PickSlipNo = @cPickSlipNo AND DropID = @cDropID AND Storerkey = @cStorerKey --ORDER BY OrderKey
               UNION
               SELECT DISTINCT lpd.OrderKey FROM dbo.PICKHEADER ph  WITH (NOLOCK) 
                  INNER JOIN LoadPlanDetail lpd  WITH (NOLOCK) ON ph.ExternOrderKey=lpd.LoadKey
                  INNER JOIN PICKDETAIL pd  WITH (NOLOCK) ON lpd.OrderKey=pd.OrderKey
                  WHERE ph.PickHeaderKey=@cPickSlipNo AND ph.Storerkey = @cStorerKey and pd.DropID = @cDropID --and isnull(ph.OrderKey,'')='' and not ph.Zone in ('XD','LB', 'LP')
               UNION
               SELECT DISTINCT rkl.OrderKey  FROM dbo.PICKHEADER ph  WITH (NOLOCK) 
                  INNER JOIN RefKeyLookup rkl  WITH (NOLOCK) ON ph.PickHeaderKey=rkl.Pickslipno
                  INNER JOIN PICKDETAIL pd  WITH (NOLOCK) ON pd.PickDetailKey=rkl.PickDetailkey
                  WHERE ph.PickHeaderKey=@cPickSlipNo AND ph.Storerkey = @cStorerKey AND pd.DropID = @cDropID --and isnull(ph.OrderKey,'')='' and ph.Zone in ('XD','LB', 'LP')
               ORDER BY OrderKey
            OPEN ordcur
            FETCH NEXT FROM ordcur INTO @cOrderKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               IF EXISTS ( SELECT * FROM dbo.ORDERS WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Storerkey = @cStorerKey AND DocType = 'N' )
               BEGIN
                  EXEC dbo.ispGenTransmitLog2
                                 @c_TableName      = 'WSTOTECFMlb',
                                 @c_Key1           = @cOrderKey,
                                 @c_Key2           = @cDropID,
                                 @c_Key3           = @cStorerKey,
                                 @c_TransmitBatch  = '',
                                 @b_success        = @bSuccess    OUTPUT,
                                 @n_err            = @nErrNo      OUTPUT,
                                 @c_errmsg         = @cErrMsg     OUTPUT

                  IF @bSuccess <> 1
                  BEGIN
                     SET @nErrNo = 249406
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS TLog2 Fail
                     GOTO Quit
                  END
               END         --end of normal order DocType = 'N'
               FETCH NEXT FROM ordcur INTO @cOrderKey
            END         --end of while
            CLOSE ordcur
            DEALLOCATE ordcur
         END      --end of @cOrderKey is empty
      END      --end of @nIsNoEmptyDropID = 1
   END      --end of dbo.fnc_GetRight( @cFacility, @cStorerKey, '', 'Innobec') = '1'
   --end of FCR-771
Quit:
END

GO