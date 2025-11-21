SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_640Matrix01                                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Show carton matrix based on SKUGROUP (Division)             */
/*                                                                      */
/* Called from: rdtfnc_TM_ClusterPick                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2021-09-07   1.0  James    WMS-17429 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_640Matrix01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cGroupKey      NVARCHAR( 10),
   @cTaskDetailKey NVARCHAR( 10),
   @cResult01      NVARCHAR( 20) OUTPUT,
   @cResult02      NVARCHAR( 20) OUTPUT,
   @cResult03      NVARCHAR( 20) OUTPUT,
   @cResult04      NVARCHAR( 20) OUTPUT,
   @cResult05      NVARCHAR( 20) OUTPUT,
   @cResult06      NVARCHAR( 20) OUTPUT,
   @cResult07      NVARCHAR( 20) OUTPUT,
   @cResult08      NVARCHAR( 20) OUTPUT,
   @nNextPage      INT           OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @curPD CURSOR
   DECLARE @cPickSlipNo    NVARCHAR( 10) = ''
   DECLARE @cCartonType    NVARCHAR( 10) = ''
   DECLARE @nCount         INT = 0
   DECLARE @nCartonNo      INT
   DECLARE @cLabelNo       NVARCHAR( 20)
   
   CREATE TABLE #CaseInfo  (  
      RowRef         BIGINT IDENTITY(1,1)  Primary Key,  
      PickSlipNo     NVARCHAR( 10),
      LabelNo        NVARCHAR( 20))  

   -- Get PickslipNo, LabelNo
   INSERT INTO #CaseInfo (PickSlipNo, LabelNo)
   SELECT DISTINCT PH.PickSlipNo, TD.Caseid
   FROM dbo.TASKDETAIL TD (NOLOCK) 
   JOIN dbo.PICKDETAIL PD (NOLOCK) ON ( TD.Caseid = PD.CaseID) 
   JOIN dbo.PackHeader PH (NOLOCK) ON ( PD.OrderKey = PH.orderkey)
   WHERE TD.Groupkey = @cGroupKey
   AND   TD.[Status] < '9'
   
   SET @nCount = 1

   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PD.PickSlipNo, PD.CartonNo, PIF.CartonType, C.LabelNo
   FROM #CaseInfo C 
   JOIN dbo.PackDetail PD WITH (NOLOCK) ON ( C.PickSlipNo = PD.PickSlipNo AND C.LabelNo = PD.LabelNo)
   JOIN dbo.PackInfo PIF WITH (NOLOCK) ON ( PD.PickSlipNo = PIF.PickSlipNo AND PD.CartonNo = PIF.CartonNo)
   JOIN dbo.CARTONIZATION CZ WITH (NOLOCK) ON ( PIF.CartonType = CZ.CartonType)
   JOIN SKU S WITH (NOLOCK) ON ( S.StorerKey = PD.Storerkey AND S.SKU = PD.SKU)
   JOIN Codelkup CLK (NOLOCK) ON 
      ( CLK.Listname = 'SKUGROUP' AND CLK.Code = S.SKUGroup AND CLK.Storerkey = S.StorerKey AND CLK.UDF01 = CZ.CartonizationGroup)
   WHERE S.StorerKey = @cStorerKey
   GROUP BY PD.PickSlipNo, PD.CartonNo, PIF.CartonType, CZ.[CUBE], CZ.UseSequence, C.LabelNo
   ORDER BY CZ.CUBE, CZ.UseSequence
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cPickSlipNo, @nCartonNo, @cCartonType, @cLabelNo
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @nCount = 1 SET @cResult01 = '1-' + @cCartonType
      IF @nCount = 2 SET @cResult02 = '2-' + @cCartonType
      IF @nCount = 3 SET @cResult03 = '3-' + @cCartonType
      IF @nCount = 4 SET @cResult04 = '4-' + @cCartonType
      IF @nCount = 5 SET @cResult05 = '5-' + @cCartonType
      IF @nCount = 6 SET @cResult06 = '6-' + @cCartonType
      IF @nCount = 7 SET @cResult07 = '7-' + @cCartonType
      IF @nCount = 8 SET @cResult08 = '8-' + @cCartonType

      UPDATE TASKDETAIL WITH (ROWLOCK) SET 
         StatusMsg = @nCount, 
         EditWho = SUSER_SNAME(), 
         EditDate = GETDATE()
      WHERE Groupkey = @cGroupKey
      AND   Caseid = @cLabelNo
      AND   STATUS = '3'
      AND   TaskType = 'CPK'
      AND   Storerkey = @cStorerKey
                  
      SET @nCount = @nCount + 1
      
      IF @nCount >= 8
         BREAK

      FETCH NEXT FROM @curPD INTO @cPickSlipNo, @nCartonNo, @cCartonType, @cLabelNo
   END
 

   Quit:
END

GO