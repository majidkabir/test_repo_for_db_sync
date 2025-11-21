SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/ 
/* Object Name: isp_FullPick_NotPACK                                       */
/* Modification History:                                                   */  
/*                                                                         */  
/* Called By:  Exceed                                                      */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Date         Author    Ver.  Purposes                                   */
/* 05-Aug-2002            1.0   Initial revision                           */
/***************************************************************************/     
CREATE PROC [dbo].[isp_FullPick_NotPACK] 
( @c_LoadKey  NVARCHAR(10)   )    
AS      
BEGIN      
 SET NOCOUNT ON        
 SET QUOTED_IDENTIFIER OFF        
 SET ANSI_NULLS OFF        
 SET CONCAT_NULL_YIELDS_NULL OFF        

Declare @nHour INT

SET @nHour  = 3             -- Hour not Pack
SET @c_LoadKey = ISNULL(RTRIM(@c_LoadKey), '')  

     
-- Order Pick more than 3 hour but not yet pack

IF OBJECT_ID('tempdb..#FullPick') IS NOT NULL 
   drop table #FullPick
 
IF OBJECT_ID('tempdb..#pick') IS NOT NULL 
   drop table #pick
 
IF OBJECT_ID('tempdb..#result') IS NOT NULL 
   drop table #result

-- Tote Fully Pick
select O.LoadKey, O.orderkey, PD.Storerkey, PD.dropID , Pickdate = Max(PD.editdate)
INTO #FullPick 
from pickdetail pd (NOLOCk) 
      JOIN orders O (NOLOCK) ON O.orderkey = pd.orderkey 
where PD.Storerkey = 'REP'
AND pd.status between '5' and '8'
and not exists ( Select 1 from Pickdetail PD2 (NOLOCK) 
            where PD2.orderkey = PD.orderkey
            AND   PD2.Status < '5' ) -- any item not pick ?
AND NOT EXISTS ( SELECT 1            -- Why not Pack ?
            FROM PackDetail pkd (NOLOCK)
            JOIN PackHeader ph  (NOLOCK) ON ph.PickSlipNo = pkd.PickSlipNo 
            WHERE ph.orderkey = PD.orderkey 
            AND PH.storerkey = PD.Storerkey )
AND ( o.LoadKey = @c_LoadKey Or @c_LoadKey = '' )     -- IF Loadkey not supply retrieve ALL
group by O.LoadKey, O.orderkey, PD.Storerkey, PD.dropID 

-- Order Pick More than 3 hour 
Select P.LoadKey, P.Storerkey, P.dropID , MAX(P.Pickdate) as Pickdate 
INTO #pick
from #FullPick P 
where DateDiff( hh , P.pickdate , getdate()) > @nHour   
Group by P.LoadKey, P.Storerkey, P.dropID 

-- Get max read time from STATION_RESPONSE
Select P.LoadKey, 
P.Storerkey, 
P.dropID , 
P.Pickdate , 
Convert(datetime, ISNULL(MAX(SR.Reading_time), '')) as Last_Reading_time
INTO #result
from #pick P 
   Left JOIN SDCWCS01.dbo.STATION_RESPONSE SR (NOLOCK) ON SR.Boxnumber = P.dropID
Group by P.LoadKey, P.Storerkey, P.dropID , P.Pickdate 

-- Get station ID
Select R.LoadKey, 
R.Storerkey, 
R.dropID , 
R.Pickdate , 
R.Last_Reading_time, 
SR.STATION
FROM #result R
   Left JOIN SDCWCS01.dbo.STATION_RESPONSE SR (NOLOCK) on ( SR.Boxnumber = R.dropID 
                                                AND SR.Reading_time = R.Last_Reading_time )
Order by R.LoadKey, R.dropID
                

drop table #FullPick
drop table #pick
drop table #result
     
END


GO