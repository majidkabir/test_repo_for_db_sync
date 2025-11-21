SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_727Inquiry20                                       */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2023-04-13 1.0  yeekung    WMS-22165 Created                            */
/* 2023-07-20 1.1  yeekung    WMS-23139 Add Total carton (yeekung01)       */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_727Inquiry20] (
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

   DECLARE @cTote       NVARCHAR (20)
   DECLARE @cWavekey    NVARCHAR(20)
   declare @cSortStaion  NVARCHAR(20)
   DECLARE @nTtlOrder   INT
   DECLARE @cOrderkey   NVARCHAR(20)
   DECLARE @cArea       NVARCHAR(20)
   DECLARE @nTtlOty     INT
   DECLARE @nTtlCtn     INT
   DECLARE @cStatus     NVARCHAR(20)
   DEclare @cCurStorerkey NVARCHAR(20)

   IF @nFunc = 727 -- General inquiry
   BEGIN
      IF @nStep = 2 -- Inquiry sub module
      BEGIN

         -- Parameter mapping
         SET @cTote = @cParam1

         -- Check blank
         IF @cTote = '' 
         BEGIN
            SET @nErrNo = 199751
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedTote
            GOTO QUIT
         END

         IF NOT EXISTS (SELECT 1 FROM PICKDETAIL (nolock)
                        WHERE DropID = @cTote
                           AND Storerkey IN ( SELECT storerkey
                                          FROM storergroup (NOLOCK)
                                          WHERE storergroup = @cStorerkey
                                          )
                           AND  STATUS < '5')
         BEGIN
            SET @nErrNo = 199752
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidTote 
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- Floor
            GOTO QUIT
         END

         IF EXISTS (SELECT 1 FROM StorerGroup (NOLOCK)
                    WHERE StorerGroup = @cStorerkey)
         BEGIN 
            SELECT @cCurStorerkey = Storerkey
            FROM PICKDETAIL (nolock)
            WHERE DropID = @cTote
               AND Storerkey IN ( SELECT storerkey
                              FROM storergroup (NOLOCK)
                              WHERE storergroup = @cStorerkey
                              )
               AND  STATUS < '5'
         END
         ELSE
         BEGIN
            SET @cCurStorerkey = @cStorerkey
         END

         SELECT @cOrderkey = Orderkey,
                @cArea = Pickzone
         FROM PICKDETAIL PD(nolock)
         JOIN LOC LOC (NOLOCK) ON PD.LOC = LOC.LOC
         where DropID = @cTote
            AND Storerkey=@cCurStorerkey
            AND  PD.status < '5'

         SELECT @cWavekey = userdefine09
         FROM Orders (nolock)
         WHERE Orderkey = @cOrderkey
            AND Storerkey=@cCurStorerkey

         SELECT @cSortStaion = userdefine01
         FROM Wave (nolock)
         WHERE Wavekey = @cWavekey

         SELECT @nTtlOrder = COUNT(DISTINCT Pickdetail.Orderkey)
         FROM PICKDETAIL (nolock)
         where DropID = @cTote
            AND Storerkey = @cCurStorerkey
            AND  STATUS < '5'


         --(yeekung01)
         SELECT @nTtlCtn = count(distinct DropID) 
         FROM Pickdetail PD  (nolock) 
            JOIN Orders O (NOLOCK) ON PD.Orderkey =O.Orderkey 
         WHERE PD.Storerkey=@cCurStorerkey
            AND Userdefine09=@cWavekey


         SELECT @nTtlOty = SUM(PD.QTY)
         FROM PICKDETAIL PD (nolock)
         where DropID = @cTote
            AND Storerkey = @cCurStorerkey
            AND  STATUS < '5'

         SET @c_oFieled01 = 'Storerkey:'
         SET @c_oFieled02 = @cCurStorerkey
         SET @c_oFieled03 = 'Wavekey:' + @cWavekey
         SET @c_oFieled04 = 'Station:' + @cSortStaion
         SET @c_oFieled05 = 'AREA:' + @cArea
         SET @c_oFieled06 = 'Total Order:' + CAST (@nTtlOrder AS NVARCHAR(5))
         SET @c_oFieled07 = 'Total Oty:' + CAST (@nTtlOty AS NVARCHAR(5))
         SET @c_oFieled08 = 'Wave Status:' 

         IF EXISTS (SELECT 1
                        FROM PICKDETAIL PD(nolock)
                        JOIN Wavedetail W (NOLOCK) ON PD.orderkey = W.orderkey
                        where W.wavekey = @cWavekey
                           AND PD.Storerkey=@cCurStorerkey
                           AND  PD.status = '0')
         BEGIN
            SET @c_oFieled09 = 'In-Process' 
         END
         ELSE
         BEGIN
            SET @c_oFieled09 = 'Picked' 
         END

         SET @c_oFieled10 = 'TTC:' + + CAST (@nTtlCtn AS NVARCHAR(5))          --(yeekung01)

         SET @nNextPage = - 1  

      END
      IF @nStep = 3 -- Inquiry sub module
      BEGIN
         -- Parameter mapping
         SET @cTote = @cParam1

         SET @cCurStorerkey = @c_oFieled02 

         IF EXISTS (SELECT 1 FROM StorerGroup (NOLOCK)
                    WHERE StorerGroup = @cStorerkey)
         BEGIN 
            SELECT @cCurStorerkey = Storerkey
            FROM PICKDETAIL (nolock)
            WHERE DropID = @cTote
               AND Storerkey IN ( SELECT storerkey
                              FROM storergroup (NOLOCK)
                              WHERE storergroup = @cStorerKey
                                    AND storerkey > @cCurStorerkey
                              )
               AND  STATUS < '5'
               
         END
         ELSE
         BEGIN
            SET @cCurStorerkey = @cStorerkey
         END

         SELECT @cOrderkey = Orderkey,
                @cArea = Pickzone
         FROM PICKDETAIL PD(nolock)
         JOIN LOC LOC (NOLOCK) ON PD.LOC = LOC.LOC
         where DropID = @cTote
            AND Storerkey=@cCurStorerkey
            AND  PD.status < '5'

         SELECT @cWavekey = userdefine09
         FROM Orders (nolock)
         WHERE Orderkey = @cOrderkey
            AND Storerkey=@cCurStorerkey

         SELECT @cSortStaion = userdefine01
         FROM Wave (nolock)
         WHERE Wavekey = @cWavekey
         
         SELECT @nTtlOrder = COUNT(DISTINCT Pickdetail.Orderkey)
         FROM PICKDETAIL (nolock)
         where DropID = @cTote
            AND Storerkey = @cCurStorerkey
            AND  STATUS < '5'

         --(yeekung01)
         SELECT @nTtlCtn = count(distinct DropID) 
         FROM Pickdetail PD  (nolock) 
            JOIN Orders O (NOLOCK) ON PD.Orderkey =O.Orderkey 
         WHERE PD.Storerkey=@cCurStorerkey
            AND Userdefine09=@cWavekey

         SELECT @nTtlOty = SUM(PD.QTY)
         FROM PICKDETAIL PD (nolock)
         where DropID = @cTote
            AND Storerkey = @cCurStorerkey
            AND  STATUS < '5'

         SET @c_oFieled01 = 'Storerkey:'
         SET @c_oFieled02 = @cCurStorerkey
         SET @c_oFieled03 = 'Wavekey:' + @cWavekey
         SET @c_oFieled04 = 'Station:' + @cSortStaion
         SET @c_oFieled05 = 'AREA:' + @cArea
         SET @c_oFieled06 = 'Total Order:' + CAST (@nTtlOrder AS NVARCHAR(5))
         SET @c_oFieled07 = 'Total Oty:' + CAST (@nTtlOty AS NVARCHAR(5))
         SET @c_oFieled08 = 'Wave Status:' 

         IF EXISTS (SELECT 1
                        FROM PICKDETAIL PD(nolock)
                        JOIN Wavedetail W (NOLOCK) ON PD.orderkey = W.orderkey
                        where W.wavekey = @cWavekey
                           AND PD.Storerkey=@cCurStorerkey
                           AND  PD.status = '0')
         BEGIN
            SET @c_oFieled09 = 'In-Process' 
         END
         ELSE
         BEGIN
            SET @c_oFieled09 = 'Picked' 
         END

         SET @c_oFieled10 = 'TTC:' + + CAST (@nTtlCtn AS NVARCHAR(5))          --(yeekung01)

         SET @nNextPage = - 1  

      END
   END

Quit:

END

GO