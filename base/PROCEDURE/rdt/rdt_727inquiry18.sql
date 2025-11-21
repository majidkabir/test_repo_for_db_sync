SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_727Inquiry18                                       */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2022-10-20 1.0  yeekung    WMS-20957 Created                            */
/***************************************************************************/
CREATE PROC [RDT].[rdt_727Inquiry18] (
 	@nMobile      INT,  
   @nFunc        INT,  
   @nStep        INT,  
   @cLangCode    NVARCHAR(3),  
   @cStorerKey   NVARCHAR(15),  
   @cOption      NVARCHAR(1),  
   @cParam1      NVARCHAR(20),  
   @cParam2      NVARCHAR(20),  
   @cParam3      NVARCHAR(20),  
   @cParam4      NVARCHAR(20),  
   @cParam5      NVARCHAR(20),  
   @c_oFieled01  NVARCHAR(20) OUTPUT,  
   @c_oFieled02  NVARCHAR(20) OUTPUT,  
   @c_oFieled03  NVARCHAR(20) OUTPUT,  
   @c_oFieled04  NVARCHAR(20) OUTPUT,  
   @c_oFieled05  NVARCHAR(20) OUTPUT,  
   @c_oFieled06  NVARCHAR(20) OUTPUT,  
   @c_oFieled07  NVARCHAR(20) OUTPUT,  
   @c_oFieled08  NVARCHAR(20) OUTPUT,  
   @c_oFieled09  NVARCHAR(20) OUTPUT,  
   @c_oFieled10  NVARCHAR(20) OUTPUT,  
   @c_oFieled11  NVARCHAR(20) OUTPUT,  
   @c_oFieled12  NVARCHAR(20) OUTPUT,  
   @nNextPage    INT          OUTPUT,  
   @nErrNo       INT          OUTPUT,  
   @cErrMsg      NVARCHAR(20) OUTPUT  
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @nErrNo = 0
   DECLARE @cID         NVARCHAR( 18)
   DECLARE @cMethod     NVARCHAR(2)
   DECLARE @cWavekey    NVARCHAR(20)
   DECLARE @cStatus     NVARCHAR(20)
   DECLARE @cTOLOC      NVARCHAR(20)
   DECLARE @nNoofTote   INT
   DECLARE @nToteCompleted INT
   DECLARE @nTotePending INT

   IF @nFunc = 727 -- General inquiry
   BEGIN
      IF @nStep = 2 -- Inquiry sub module
      BEGIN

         -- Parameter mapping
         SET @cMethod = @cParam1
         SET @cID = @cParam3

         -- Check blank
         IF @cID = '' 
         BEGIN
            SET @nErrNo = 193051
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CaseID
            GOTO QUIT
         END

         -- Check blank
         IF @cMethod = '' 
         BEGIN
            SET @nErrNo = 193052
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Method
            GOTO QUIT
         END

         IF @cMethod NOT IN ('1','2')
         BEGIN
            SET @nErrNo = 193053
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidMethod
            GOTO QUIT
         END
         
         IF  @cMethod ='1'
         BEGIN
            SELECT TOP 1 @cWavekey = wavekey,
                   @cTOLOC = toloc
            FROM taskdetail (NOLOCK)
            where  caseid=@cID
            AND storerkey =@cStorerKey 
            Order by editdate desc

            -- Check pallet valid
            IF @@ROWCOUNT = ''
            BEGIN
         	   SET @nErrNo = 193054
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidCaseID
               GOTO QUIT
            END
         END
         ELSE IF  @cMethod ='2'
         BEGIN
            SELECT TOP 1 @cWavekey = wavekey,
                   @cTOLOC = toloc  
            FROM taskdetail (NOLOCK)
            where dropid=@cID
               AND storerkey =@cStorerKey 
            order by editdate desc

            -- Check pallet valid
            IF ISNULL(@cWavekey,'') = ''
            BEGIN
         	   SET @nErrNo = 193055
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidDropID
               GOTO QUIT
            END
         END

         SELECT @nNoofTote = count(distinct caseid)
         FROM taskdetail (NOLOCK)
         where wavekey=@cwavekey
         AND storerkey =@cStorerKey 

         SELECT @nToteCompleted= count(distinct caseid)
         FROM taskdetail (NOLOCK)
         where status='9'
         and wavekey=@cwavekey 
         AND storerkey =@cStorerKey 
            
         SELECT @nTotePending= count(distinct caseid)
         FROM taskdetail (NOLOCK)
         where status<>'9'
         and wavekey=@cwavekey
         AND storerkey =@cStorerKey 

         IF @nNoofTote=@nToteCompleted
            SET @cstatus='Complete'
         ELSE
            SET @cstatus='NotComplete'

         -- Get label
         SET @c_oFieled01 = rdt.rdtgetmessage( 193056, @cLangCode, 'DSP') --Wavekey: 
         SET @c_oFieled02 = @cWavekey
         SET @c_oFieled03 = rdt.rdtgetmessage( 193057, @cLangCode, 'DSP') --Station:
         SET @c_oFieled04 = @cTOLOC
         SET @c_oFieled05 = rdt.rdtgetmessage( 193058, @cLangCode, 'DSP') --Status:
         SET @c_oFieled06 = @cstatus
         SET @c_oFieled07 = SUBSTRING(rdt.rdtgetmessage( 193059, @cLangCode, 'DSP'),1,10) + CAST (@nNoofTote AS NVARCHAR(5))
         SET @c_oFieled08 = SUBSTRING(rdt.rdtgetmessage( 193060, @cLangCode, 'DSP'),1,10) + CAST (@nToteCompleted AS NVARCHAR(5))
         SET @c_oFieled09 = SUBSTRING(rdt.rdtgetmessage( 193061, @cLangCode, 'DSP'),1,10) + CAST (@nTotePending AS NVARCHAR(5))

      	SET @nNextPage = 1  
      END
   END

Quit:

END

GO