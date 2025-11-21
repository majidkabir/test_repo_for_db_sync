SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC [RDT].[rdt_PurgeTraceRecord] 
  @nNoOfDayRetain INT = 7 
AS 
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

declare @nRowRef int

declare c_mobile cursor local fast_forward read_only for 
select RowRef 
from rdt.RDTTRace (nolock) 
where datediff(day, StartTime, getdate()) > @nNoOfDayRetain 
order by RowRef 

open c_mobile

fetch next from c_mobile into @nRowRef   
while @@fetch_status <> -1
begin
   set rowcount 1

   begin tran 
   
   delete rdt.RDTTRace with (rowlock) 
   where  RowRef = @nRowRef 

   while @@trancount > 0 
      commit tran 

   set rowcount 0       
   fetch next from c_mobile into @nRowRef 
end 
close c_mobile
deallocate c_mobile



GO