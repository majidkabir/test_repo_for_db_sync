SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Proc : isp_ReSubmit_OWDPREPICK                                   */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: Resubmit E1 interfaces                                         */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Local Variables:                                                        */
/*                                                                         */
/* Called By: Back-end job                                                 */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date              Author         Ver      Purposes                      */
/*                                                                         */
/***************************************************************************/
CREATE PROC [dbo].[isp_ReSubmit_OWDPREPICK]
AS
BEGIN
   declare @cWaveKey nvarchar(10)

   declare c_missing_wavekey cursor local fast_forward read_only for
   select distinct p.wavekey
   from pickheader p (nolock)
   join orders o (nolock) on p.orderkey = o.orderkey
   join wavedetail w (nolock) on w.orderkey = o.orderkey
   join storerconfig s (nolock) on s.storerkey = o.storerkey and s.configkey = 'DPREPICK' and svalue = '1'
   left outer join transmitlog t (nolock) on t.key1 = o.orderkey and t.TableName = 'OWDPREPICK'
   where t.key1 is null
   and datediff(day, p.adddate, getdate()) < 2

   Open c_missing_wavekey

   fetch next from c_missing_wavekey into @cWaveKey
   while @@fetch_status <> -1
   begin
      EXEC ispExportAllocatedOrd
         @c_Key   = @cWaveKey,
         @c_Type  = 'WAVE',
         @b_success  =0,
         @n_err      =0,
         @c_errmsg   = ''

   --   insert into TraceInfo(TraceName, TimeIn)
   --   values ('Resubmit OWDPREPICK into TransmitLog WaveKey = ' + isnull(rtrim(@cWaveKey), ''), GetDate())
      fetch next from c_missing_wavekey into @cWaveKey

   end
   close c_missing_wavekey
   deallocate c_missing_wavekey
END -- Procedure

GO