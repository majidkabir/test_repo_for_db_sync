SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Cluster_Pick_UpdatePack                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Comfirm Pick                                                */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 30-Dec-2010 1.0  James       Created                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_Cluster_Pick_UpdatePack] (
   @nMobile          INT, 
   @nFunc            INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cUserName        NVARCHAR( 15), 
   @cFacility        NVARCHAR(  5), 
   @cPickSlipNo      NVARCHAR( 10), 
   @cLangCode        NVARCHAR(  3), 
   @nErrNo           INT          OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT 

)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @b_Success          INT,
           @n_err              INT, 
           @c_authority        NVARCHAR(1), 
           @n_ttlcnts          INT, 
           @c_CartonGroup      NVARCHAR(10),   
           @c_CartonType       NVARCHAR(10),   
           @n_CartonCube       FLOAT,   
           @n_TotalWeight      FLOAT,   
           @n_PackedCube       FLOAT,   
           @n_TotalCube        FLOAT,   
           @n_TotalCarton      INT,   
   		  @cOrderKey          NVARCHAR( 10), 
   		  @cLoadKey           NVARCHAR( 10), 
           @nTranCount         INT,
           @cDefaultCartonType NVARCHAR(10),   
           @nPackDetCtn        INT,   
           @cCtnTyp1           NVARCHAR(10),  
           @cCtnTyp2           NVARCHAR(10),  
           @cCtnTyp3           NVARCHAR(10),  
           @cCtnTyp4           NVARCHAR(10),  
           @cCtnTyp5           NVARCHAR(10),  
           @nCtnCnt1           INT,  
           @nCtnCnt2           INT,  
           @nCtnCnt3           INT,  
           @nCtnCnt4           INT,  
           @nCtnCnt5           INT,    
           @nCtnCnt            INT,   
           @nCartonCnt         INT,   
           @nCartonWeight      FLOAT,    
           @c_errmsg           NVARCHAR( 20)

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN Cluster_Pick_UpdatePack

	DECLARE C_PckHdrUpd CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT OrderKey, LoadKey 
   FROM PackHeader WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo
  	AND STATUS = '9' 
  	ORDER BY OrderKey
   
   OPEN C_PckHdrUpd
   FETCH NEXT FROM C_PckHdrUpd INTO @cOrderKey, @cLoadKey
   WHILE @@FETCH_STATUS <> -1 
   BEGIN
	   SELECT @b_Success = 0
	   EXECUTE dbo.nspGetRight null,  -- facility
	      @cStorerKey,    -- Storerkey
	      null,            -- Sku
	      'AutoPackConfirm',  -- Configkey
	      @b_Success    OUTPUT,
	      @c_authority  OUTPUT,
	      @n_err        OUTPUT,
	      @c_errmsg     OUTPUT
	
      IF @b_Success <> 1
      BEGIN
         SET @nErrNo = 71841
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'nspGetRight'
         GOTO RollBackTran
      END
      ELSE IF @c_authority = '1'
      BEGIN
			SELECT @n_ttlcnts = COUNT(DISTINCT PD.Cartonno)
			FROM PACKHEADER PH WITH (NOLOCK)
			JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.pickslipno = PD.pickslipno)
			WHERE PH.Status = '9' 
			AND PH.Orderkey = @cOrderKey
			AND PH.Pickslipno = @cPickSlipNo
		 					
			IF @n_ttlcnts > 0
			BEGIN
				UPDATE MBOLDETAIL WITH (ROWLOCK)
				SET TotalCartons = @n_ttlcnts,
				Trafficcop = NULL
				WHERE Orderkey = @cOrderKey
			 	 
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 71842
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CfmPack Fail'
               GOTO RollBackTran
            END
			END
		END	-- @c_authority = '1'

      IF RTRIM(@cStorerKey) = '' OR @cStorerKey IS NULL
      BEGIN
         SELECT TOP 1 @cStorerKey = ORDERS.StorerKey
         FROM ORDERS WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
      END
      
      IF NOT EXISTS(SELECT 1 FROM StorerConfig WITH (NOLOCK) 
              WHERE StorerKey = @cStorerKey 
                   AND   ConfigKey = 'PackSummB4Packed' 
                   AND   sValue = '1')
      BEGIN 
			SELECT @c_CartonGroup = CartonGroup
			FROM   STORER WITH (NOLOCK)
			WHERE  StorerKey = @cStorerKey
			
			SELECT TOP 1 
				@cDefaultCartonType = CartonType,
				@n_CartonCube        = [Cube]
			FROM  CARTONIZATION WITH (NOLOCK)
			WHERE CartonizationGroup = @c_CartonGroup
			ORDER BY UseSequence ASC
			
			SELECT @nPackDetCtn = COUNT(DISTINCT CartonNo),
					 @n_PackedCube = @n_CartonCube * COUNT(DISTINCT CartonNo)
			FROM   PACKDETAIL WITH (NOLOCK)
			WHERE PickSlipNo = @cPickSlipNo
      
         -- Check whether the PackInfo exists? if Yes, then PackInfo will overwrite pack summary
         IF EXISTS(SELECT 1 FROM PACKINFO WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
         BEGIN
            SELECT @cCtnTyp1 = '', @cCtnTyp2 = '', @cCtnTyp3 = '', @cCtnTyp4 = '', @cCtnTyp5 = ''
            SELECT @nCtnCnt1 = 0, @nCtnCnt2 = 0, @nCtnCnt3 = 0, @nCtnCnt4 = 0, @nCtnCnt5 = 0
            SET @n_TotalWeight = 0
            SET @n_TotalCube = 0
            SET @n_TotalCarton = 0
      
            SET @nCtnCnt = 1
            DECLARE CUR_PACKINFO_CARTON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT CartonType,
            COUNT(DISTINCT CartonNo),
            SUM(ISNULL(PACKINFO.Weight,0)),
            SUM(ISNULL(PACKINFO.Cube,0))
            FROM   PACKINFO WITH (NOLOCK)
            WHERE  PickSlipNo = @cPickSlipNo 
            AND    (CartonType <> '' AND CartonType IS NOT NULL)
         	GROUP BY CartonType
      
            OPEN CUR_PACKINFO_CARTON
				FETCH NEXT FROM CUR_PACKINFO_CARTON INTO @c_CartonType, @nCartonCnt, @nCartonWeight, @n_CartonCube
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF @nCtnCnt = 1
               BEGIN
                  SET @cCtnTyp1 = @c_CartonType
                  SET @nCtnCnt1 = @n_TotalCarton
               END
               IF @nCtnCnt = 2
               BEGIN
                  SET @cCtnTyp2 = @c_CartonType
                  SET @nCtnCnt2 = @n_TotalCarton
               END
               IF @nCtnCnt = 3
               BEGIN
                  SET @cCtnTyp3 = @c_CartonType
                  SET @nCtnCnt3 = @n_TotalCarton
               END
               IF @nCtnCnt = 4
               BEGIN
                  SET @cCtnTyp4 = @c_CartonType
                  SET @nCtnCnt4 = @n_TotalCarton
               END
               IF @nCtnCnt = 5
               BEGIN
                  SET @cCtnTyp5 = @c_CartonType
                  SET @nCtnCnt5 = @n_TotalCarton
               END
               SET @n_TotalWeight = @n_TotalWeight + @nCartonWeight
               SET @n_TotalCube   = @n_TotalCube   + @n_CartonCube
               SET @n_TotalCarton = @n_TotalCarton + @nCartonCnt

               SET @nCtnCnt = @nCtnCnt + 1
               FETCH NEXT FROM CUR_PACKINFO_CARTON INTO @c_CartonType, @nCartonCnt, @nCartonWeight, @n_CartonCube
            END
            CLOSE CUR_PACKINFO_CARTON
            DEALLOCATE CUR_PACKINFO_CARTON
			END -- Packinfo exists
         ELSE
         BEGIN
            SELECT @nCtnCnt1 = ISNULL(CtnCnt1,0),
                   @nCtnCnt2 = ISNULL(CtnCnt2,0),
                   @nCtnCnt3 = ISNULL(CtnCnt3,0),
                   @nCtnCnt4 = ISNULL(CtnCnt4,0),
                   @nCtnCnt5 = ISNULL(CtnCnt5,0),
                   @cCtnTyp1 = CtnTyp1,
                   @cCtnTyp2 = CtnTyp2,
                   @cCtnTyp3 = CtnTyp3,
                   @cCtnTyp4 = CtnTyp4,
                   @cCtnTyp5 = CtnTyp5,
                   @n_TotalWeight = TotCtnWeight,
                   @n_TotalCube = TotCtnCube
            FROM PACKHEADER WITH (NOLOCK)
            WHERE PICKSLIPNO = @cPickSlipNo
      
            IF @n_TotalWeight IS NULL OR @n_TotalWeight = 0
            BEGIN
               SELECT @n_TotalWeight = SUM(SKU.STDNETWGT * PACKDETAIL.Qty)
               FROM   PACKDETAIL WITH (NOLOCK)
               JOIN   SKU WITH (NOLOCK) ON PACKDETAIL.StorerKey = SKU.StorerKey AND PACKDETAIL.SKU = SKU.SKU
               WHERE  PACKDETAIL.PickSlipNo = @cPickSlipNo
            END
            
            IF (@nCtnCnt1 + @nCtnCnt2 + @nCtnCnt3 + @nCtnCnt4 + @nCtnCnt5) = 0
            BEGIN
               SELECT @cCtnTyp1 = @cDefaultCartonType,
               @nCtnCnt1 = @nPackDetCtn,
               @n_TotalCube = @n_PackedCube
            END
			END
      
         IF (@nCtnCnt1 + @nCtnCnt2 + @nCtnCnt3 + @nCtnCnt4 + @nCtnCnt5) <> @nPackDetCtn
         BEGIN
            IF @cCtnTyp1 = @cDefaultCartonType
               SET @nCtnCnt1 = @nPackDetCtn - (@nCtnCnt2 + @nCtnCnt3 + @nCtnCnt4 + @nCtnCnt5)
            IF @cCtnTyp2 = @cDefaultCartonType
               SET @nCtnCnt2 = @nPackDetCtn - (@nCtnCnt1 + @nCtnCnt3 + @nCtnCnt4 + @nCtnCnt5)
            IF @cCtnTyp3 = @cDefaultCartonType
               SET @nCtnCnt1 = @nPackDetCtn - (@nCtnCnt2 + @nCtnCnt1 + @nCtnCnt4 + @nCtnCnt5)
            IF @cCtnTyp4 = @cDefaultCartonType
               SET @nCtnCnt4 = @nPackDetCtn - (@nCtnCnt2 + @nCtnCnt3 + @nCtnCnt1 + @nCtnCnt5)
            IF @cCtnTyp5 = @cDefaultCartonType
               SET @nCtnCnt1 = @nPackDetCtn - (@nCtnCnt2 + @nCtnCnt3 + @nCtnCnt4 + @nCtnCnt1)
         END
      
         UPDATE PACKHEADER
         SET CtnCnt1 = @nCtnCnt1,
             CtnCnt2 = @nCtnCnt2,
             CtnCnt3 = @nCtnCnt3,
             CtnCnt4 = @nCtnCnt4,
             CtnCnt5 = @nCtnCnt5,
             CtnTyp1 = @cCtnTyp1,
             CtnTyp2 = @cCtnTyp2,
             CtnTyp3 = @cCtnTyp3,
             CtnTyp4 = @cCtnTyp4,
             CtnTyp5 = @cCtnTyp5,
             TotCtnWeight = @n_TotalWeight,
             TotCtnCube   = @n_TotalCube,
             CartonGroup  = @c_CartonGroup
         WHERE PICKSLIPNO = @cPickSlipNo

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 71843
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CfmPack Fail'
            GOTO RollBackTran
         END
               
         UPDATE LOADPLAN WITH (ROWLOCK)
         SET CtnCnt1 = PH.CtnCnt1,
             CtnCnt2 = PH.CtnCnt2,
             CtnCnt3 = PH.CtnCnt3,
             CtnCnt4 = PH.CtnCnt4,
             CtnCnt5 = PH.CtnCnt5,
             CtnTyp1 = PH.CtnTyp1,
             CtnTyp2 = PH.CtnTyp2,
             CtnTyp3 = PH.CtnTyp3,
             CtnTyp4 = PH.CtnTyp4,
             CtnTyp5 = PH.CtnTyp5,
             TotCtnWeight = ISNULL(PH.TotCtnWeight,0),
             TotCtnCube   = ISNULL(PH.TotCtnCube,0),
             CartonGroup  = PH.CartonGroup
         FROM LOADPLAN
         JOIN ( SELECT PACKHEADER.LoadKey,
                       MAX(PACKHEADER.CartonGroup) AS CartonGroup,
                       SUM(ISNULL(CtnCnt1,0)) AS CtnCnt1,
                       SUM(ISNULL(CtnCnt2,0)) AS CtnCnt2,
                       SUM(ISNULL(CtnCnt3,0)) AS CtnCnt3,
                       SUM(ISNULL(CtnCnt4,0)) AS CtnCnt4,
                       SUM(ISNULL(CtnCnt5,0)) AS CtnCnt5,
                       SUM(ISNULL(TotCtnWeight,0)) AS TotCtnWeight,
                       SUM(ISNULL(TotCtnCube,0)) AS TotCtnCube,
                       MAX(CtnTyp1) AS CtnTyp1,
                       MAX(CtnTyp2) AS CtnTyp2,
                       MAX(CtnTyp3) AS CtnTyp3,
                       MAX(CtnTyp4) AS CtnTyp4,
                       MAX(CtnTyp5) AS CtnTyp5
                FROM PACKHEADER WITH (NOLOCK)
                WHERE LoadKey = @cLoadKey
                GROUP BY PACKHEADER.LoadKey) AS PH ON PH.LoadKey = LOADPLAN.LoadKey
         WHERE LOADPLAN.LoadKey = @cLoadKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 71844
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CfmPack Fail'
            GOTO RollBackTran
         END
		END -- StorerConfig 'PackSummB4Packed' Not turn On.
      FETCH NEXT FROM C_PckHdrUpd INTO @cOrderKey, @cLoadKey
   END
   CLOSE C_PckHdrUpd
   DEALLOCATE C_PckHdrUpd
         
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN Cluster_Pick_UpdatePack

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN Cluster_Pick_UpdatePack
END

GO