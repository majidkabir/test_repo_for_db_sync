SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_UA_GETTASK_02                                   */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Get next SKU to Pick, ORDER seq as below                    */  
/*          If there is pack requirement on the order header level      */
/*          (Orders.Userdefine10<>ÆÆ), sort the pick detail by          */
/*          COO(Lotattribute.Lottable08), sku                           */
/*          Else sort the pick detail by COO, logicalloc,loc            */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 12-Jun-2012 1.0  James       SOS247205 - Created                     */  
/* 24-06-2015  1.1  James       Update sorting seq                      */
/* 20-08-2015  1.2  ChewKP      Change Sorting Sequence (ChewKP01)      */
/* 27-10-2016  1.3  James       Perf tuning                             */
/************************************************************************/  

CREATE PROC [RDT].[rdt_UA_GETTASK_02] (  
   @n_Mobile                  INT, 
   @n_Func                    INT, 
   @c_StorerKey               NVARCHAR( 15),  
   @c_UserName                NVARCHAR( 15),  
   @c_Facility                NVARCHAR( 5),  
   @c_PutAwayZone             NVARCHAR( 10),  
   @c_PickZone                NVARCHAR( 10),  
   @c_LangCode                NVARCHAR( 3),  
	@c_oFieled01               NVARCHAR( 20)      OUTPUT,
	@c_oFieled02               NVARCHAR( 20)      OUTPUT,
   @c_oFieled03               NVARCHAR( 20)      OUTPUT,
   @c_oFieled04               NVARCHAR( 20)      OUTPUT,
   @c_oFieled05               NVARCHAR( 20)      OUTPUT,
   @c_oFieled06               NVARCHAR( 20)      OUTPUT,
   @c_oFieled07               NVARCHAR( 20)      OUTPUT,
   @c_oFieled08               NVARCHAR( 20)      OUTPUT,
   @c_oFieled09               NVARCHAR( 20)      OUTPUT,
   @c_oFieled10               NVARCHAR( 20)      OUTPUT,
	@c_oFieled11               NVARCHAR( 20)      OUTPUT,
	@c_oFieled12               NVARCHAR( 20)      OUTPUT,
   @c_oFieled13               NVARCHAR( 20)      OUTPUT,
   @c_oFieled14               NVARCHAR( 20)      OUTPUT,
   @c_oFieled15               NVARCHAR( 20)      OUTPUT, 
   @b_Success                 INT                OUTPUT, 
   @nErrNo                    INT                OUTPUT,   
   @cErrMsg                   NVARCHAR( 20)      OUTPUT 
)  
AS  
BEGIN  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cSize_Seq         NVARCHAR( 30), 
           @n_MultiStorer     INT, 
           @n_Cnt             INT 

   DECLARE @cSQL                NVARCHAR( MAX),
           @cExecStatements     NVARCHAR( MAX),
           @cExecArguments      NVARCHAR( MAX)


   SET @n_Cnt = 0
   SET @cSQL = ''
   SET @cSQL = 
      ' SELECT @n_Cnt = COUNT ( 1) ' + 
      ' FROM RDT.RDTPickLock RPL WITH (NOLOCK) ' + 
      ' JOIN dbo.Orders O WITH (NOLOCK, INDEX(PKOrders) ) ON RPL.OrderKey = O.OrderKey ' + 
      ' WHERE RPL.Status < ''9'' ' + 
      ' AND   RPL.AddWho = @c_UserName ' 

   IF @c_PutAwayZone <> 'ALL' 
      SET @cSQL = @cSQL + ' AND   RPL.PutAwayZone = @c_PutAwayZone '

   IF @c_PickZone <> '' 
      SET @cSQL = @cSQL + ' AND   RPL.PickZone =  @c_PickZone '

   SET @cSQL = @cSQL + ' AND   ISNULL( O.Userdefine10, '''') <> '''' '

   SET @cExecStatements = @cSQL 

   SET @cExecArguments =  N'@c_UserName      NVARCHAR( 18), ' +
                           '@c_PutAwayZone   NVARCHAR( 10), ' + 
                           '@c_PickZone      NVARCHAR( 10), ' + 
                           '@n_Cnt           INT     OUTPUT ' 

   EXEC sp_ExecuteSql @cExecStatements
                     ,@cExecArguments
                     ,@c_UserName
                     ,@c_PutAwayZone   
                     ,@c_PickZone
                     ,@n_Cnt     OUTPUT

   SET @cSQL = ''
   SET @cSQL = 
        ' SELECT TOP 1 ' + 
        '    @c_oFieled01   = PD.Loc,        ' +
        '    @c_oFieled02   = PD.OrderKey,   ' +
        '    @c_oFieled03   = SKU.SKU,       ' +
        '    @c_oFieled04   = SKU.DESCR,     ' +
        '    @c_oFieled05   = SKU.Style,     ' +
        '    @c_oFieled06   = SKU.Color,     ' +
        '    @c_oFieled07   = SKU.Size,      ' +
        '    @c_oFieled08   = SKU.BUSR7,     ' +
        '    @c_oFieled09   = PD.LOT,        ' +
        '    @c_oFieled10   = PD.PickSlipNo  ' +
        ' FROM RDT.RDTPickLock RPL WITH (NOLOCK) ' +
        ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RPL.StorerKey = PD.StorerKey AND RPL.OrderKey = PD.OrderKey) ' +
        ' JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU) ' +
        ' JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC) ' 
         
   IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) WHERE ListName = 'CLPLOCTYPE' AND ISNULL( CODE, '') <> '' AND StorerKey = @c_StorerKey)
      SET @cSQL = @cSQL + 
         ' JOIN dbo.CODELKUP CLK WITH (NOLOCK) ON ( L.LocationType = CLK.Code AND ListName = ''CLPLOCTYPE'') '

   SET @cSQL = @cSQL +
         ' WHERE RPL.StorerKey = @c_StorerKey ' + 
         ' AND RPL.Status < ''9'' ' + 
         ' AND RPL.AddWho = @c_UserName ' +
         ' AND PD.Status = ''0'' ' +
         ' AND L.Facility = @c_Facility  ' +
         ' AND CLK.Storerkey = @c_StorerKey  ' 

   IF @c_PutAwayZone <> 'ALL' 
      SET @cSQL = @cSQL + ' AND   L.PutAwayZone = @c_PutAwayZone '

   IF @c_PickZone <> '' 
      SET @cSQL = @cSQL + ' AND   L.PickZone =  @c_PickZone '

   IF @n_Cnt > 0
      SET @cSQL = @cSQL + ' ORDER BY PD.SKU, L.LogicalLocation, L.LOC'
   ELSE
      SET @cSQL = @cSQL + ' ORDER BY L.LogicalLocation, L.LOC'

   SET @cExecStatements = @cSQL 

   SET @cExecArguments =  N'@c_StorerKey     NVARCHAR( 15), ' +
                           '@c_UserName      NVARCHAR( 18), ' +
                           '@c_Facility      NVARCHAR( 5), ' +
                           '@c_PutAwayZone   NVARCHAR( 10), ' + 
                           '@c_PickZone      NVARCHAR( 10), ' + 
                           '@c_oFieled01     NVARCHAR( 20)     OUTPUT, ' +
                           '@c_oFieled02     NVARCHAR( 20)     OUTPUT, ' +
                           '@c_oFieled03     NVARCHAR( 20)     OUTPUT, ' +
                           '@c_oFieled04     NVARCHAR( 20)     OUTPUT, ' +
                           '@c_oFieled05     NVARCHAR( 20)     OUTPUT, ' +
                           '@c_oFieled06     NVARCHAR( 20)     OUTPUT, ' +
                           '@c_oFieled07     NVARCHAR( 20)     OUTPUT, ' +
                           '@c_oFieled08     NVARCHAR( 20)     OUTPUT, ' +
                           '@c_oFieled09     NVARCHAR( 20)     OUTPUT, ' +
                           '@c_oFieled10     NVARCHAR( 20)     OUTPUT  ' 

   EXEC sp_ExecuteSql @cExecStatements
                     ,@cExecArguments
                     ,@c_StorerKey
                     ,@c_UserName
                     ,@c_Facility
                     ,@c_PutAwayZone   
                     ,@c_PickZone
                     ,@c_oFieled01  OUTPUT
                     ,@c_oFieled02  OUTPUT
                     ,@c_oFieled03  OUTPUT
                     ,@c_oFieled04  OUTPUT
                     ,@c_oFieled05  OUTPUT
                     ,@c_oFieled06  OUTPUT
                     ,@c_oFieled07  OUTPUT
                     ,@c_oFieled08  OUTPUT
                     ,@c_oFieled09  OUTPUT
                     ,@c_oFieled10  OUTPUT                                                                                                                                                                                             

   SELECT 
      @c_oFieled11   = ExternOrderKey,  
      @c_oFieled12   = ConsigneeKey  
   FROM dbo.Orders WITH (NOLOCK) 
   WHERE StorerKey = @c_StorerKey  
      AND OrderKey = @c_oFieled02
END 

GO