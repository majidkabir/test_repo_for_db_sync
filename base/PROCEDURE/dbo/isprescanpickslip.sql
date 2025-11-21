SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* SP: ispReScanPickSlip                                                */
/* Creation Date: 16-June-2005                                          */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Re-Scan all the Conso/Normal PickSlip is Scan-out date      */
/*          not equal to NULL and Order Status not change to 5          */
/* Usage:                                                               */
/*                                                                      */
/* Called By: Schedule Job or user Manually Run                         */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 16-June-2005 Shong                                                   */
/************************************************************************/
CREATE PROC [dbo].[ispReScanPickSlip] 
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   declare @pickslipno  NVARCHAR(10)
   
   declare rescan_cur cursor fast_forward read_only for
   select distinct p.pickslipno
   from pickinginfo p (nolock)
   join pickheader ph (nolock) on p.pickslipno = ph.pickheaderkey  
   join orderdetail o (nolock) on o.orderkey = ph.orderkey 
   where ph.orderkey <> ''
   and o.status < '5'
   and o.qtyallocated + o.qtypicked > 0 
   and p.scanoutdate is not null 
   and ph.zone not in ('XD','LB')
   union 
   select distinct p.pickslipno
   from pickinginfo p (nolock)
   join pickheader ph (nolock) on p.pickslipno = ph.pickheaderkey  
   join orderdetail o (nolock) on o.loadkey = ph.externorderkey
   where ph.orderkey = ''
   and o.status < '5'
   and p.scanoutdate is not null 
   and o.qtyallocated + o.qtypicked > 0 
   and ph.zone not in ('XD','LB')
   open rescan_cur
   
   fetch next from rescan_cur into @pickslipno
   
   while @@fetch_status <> -1
   begin
      print 'updateing ' + @pickslipno
      update pickinginfo set scanoutdate = getdate() where pickslipno = @pickslipno
   
      fetch next from rescan_cur into @pickslipno
   end 
   close rescan_cur
   deallocate rescan_cur 
END

GO