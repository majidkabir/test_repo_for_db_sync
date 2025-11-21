SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/ 
/* Object Name: isp_get_lp_vehicle                                         */
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
CREATE procedure [dbo].[isp_get_lp_vehicle](
    @c_loadkey NVARCHAR(10)
 )
 as
 begin
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
 declare @c_vehicle NVARCHAR(10)
 declare @c_vehicleno NVARCHAR(255)
 set @c_vehicleno = "*"
 set @c_vehicle = ""
 declare cur5 cursor FAST_FORWARD READ_ONLY
 for
 select vehiclenumber from ids_lp_vehicle(nolock)
 where loadkey = @c_loadkey
 order by linenumber
 open cur5
 fetch next from cur5 into @c_vehicle
 while (@@fetch_status=0)
    begin
 	IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_vehicleno)) <> '' AND (dbo.fnc_LTrim(dbo.fnc_RTrim(@c_vehicleno)) <> '*')
 		SELECT @c_vehicleno = @c_vehicleno + ' / '
       set @c_vehicleno =    @c_vehicleno + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_vehicle)) -- + ' / '
       fetch next from cur5 into @c_vehicle
    end
 close cur5
 deallocate cur5
 select Left(@c_vehicleno, 255) -- dbo.fnc_RTrim(substring(@c_vehicleno,1,len(@c_vehicleno)-2))
 end


GO